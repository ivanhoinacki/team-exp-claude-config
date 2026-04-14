---
name: validate-migration
description: Validate database migration safety before merge. Checks rollback plan, backwards compatibility, performance impact, and lock duration. Use when creating migrations, altering tables, adding indexes, or when the user says "validate migration", "check migration", "migration safe?", "migration ok?", "can I run this migration?".
argument-hint: [migration-file-path]
allowed-tools: Bash(git *), Bash(GIT_EDITOR=true git *), Read, Glob, Grep, Edit, Task
---

# Validate Migration

## Working Directories

1. **Obsidian workspace**: `__VAULT_ROOT__`
2. **Codebase**: `__CODEBASE_ROOT__`

---

## Common Agent Mistakes

1. **No rollback plan**: Approving a migration without verifying `down()` exists and is correct. Every migration MUST have a working rollback or explicit acknowledgment of irreversibility.
2. **Missing CONCURRENTLY**: Not flagging `CREATE INDEX` without `CONCURRENTLY` on any table. This locks the table for writes during index creation.
3. **Ignoring dual-database (svc-experiences)**: Validating the migration SQL but not reminding about the dual-database requirement. Both dev and spec databases need migration.
4. **Underestimating table size**: Not checking the large table risk list before approving an ALTER TABLE. Always cross-reference Phase 2 table.
5. **Single-step risky operations**: Not suggesting zero-downtime recipes for column renames, type changes, or constraint additions on large tables. Always recommend the multi-step approach.
6. **Transaction + CONCURRENTLY conflict**: Not catching `CREATE INDEX CONCURRENTLY` inside a transaction. TypeORM wraps migrations in transactions by default.

---

## Phase 0: Discover and Classify

### Find migration files

1. If `$ARGUMENTS` provided, use that path directly
2. Otherwise, find migration files in the current branch diff:

```bash
GIT_EDITOR=true git diff --name-only main...HEAD | grep -iE "(migrat|\.sql)"
```

### Detect ORM framework

| Service         | ORM       | Migration format                      | Location             |
| --------------- | --------- | ------------------------------------- | -------------------- |
| svc-experiences | TypeORM   | TypeScript classes with `up()/down()` | `src/migration/`     |
| svc-order       | Sequelize | JS files with `up()/down()`           | `db/migrations/`     |
| svc-ee-offer    | Sequelize | JS files                              | `db/migrations/`     |
| svc-search      | Sequelize | JS files                              | `db/migrations/`     |
| svc-auth        | Prisma    | `.prisma` schema + SQL                | `prisma/migrations/` |

If unknown, detect from the migration file format and `package.json` dependencies.

### Detect database features

Check if the service uses special PostgreSQL features:

- **PostGIS** (svc-experiences, svc-search): spatial columns (`geometry`, `geography`), spatial indexes (`GIST`)
- **JSONB**: JSON columns with GIN indexes
- **Enums**: custom PostgreSQL enum types
- **Extensions**: `uuid-ossp`, `postgis`, etc.

### Dual-database check (svc-experiences)

svc-experiences has TWO databases that need migrations:

- `svc_experiences_development` (port 5432), dev database
- `svc_experiences_spec` (port 5432, APP_ENV=spec), test database

Both must be migrated before tests will pass.

---

## Phase 1: Parallel Analysis (subagents)

Launch 2 subagents in parallel:

### Agent 1: Migration Safety Analysis

```
Read each migration file completely. For EACH migration, analyze:

1. ROLLBACK SAFETY
   - Does down() exist and revert ALL changes from up()?
   - Does down() handle IF EXISTS for idempotency?
   - Would running down() on a populated table lose data?
   - Are there data transformations in up() that can't be reversed?

2. BACKWARD COMPATIBILITY
   - Column removal: is the column still referenced in models, queries, ORM mappings?
   - Column rename: needs two-phase deploy (add new -> migrate data -> remove old)
   - Type change: is the new type compatible with existing data?
   - NOT NULL added: does existing data satisfy it? Is there a DEFAULT?
   - Index removal: will any query become a full table scan?
   - Constraint added: does existing data satisfy it?
   - Enum changes: values added (safe) vs replaced (unsafe)?

3. PERFORMANCE IMPACT
   - Is this an ALTER on a known large table? (see large table list)
   - ADD COLUMN with DEFAULT: safe in PG11+ (no rewrite)
   - CREATE INDEX: is it CONCURRENTLY? (non-concurrent locks table)
   - Data migration: how many rows? Is it batched?
   - Transaction scope: is the whole migration in one transaction?

Return: findings per migration with severity (CRITICAL/HIGH/MEDIUM/LOW).
```

### Agent 2: Model and Schema Consistency

```
For each migration in the branch:

1. MODEL CONSISTENCY
   - Read the ORM model/entity that maps to the affected table
   - Verify every column added/modified in the migration has a corresponding model field
   - Verify column types match between migration and model
   - Check for @Column decorators (TypeORM) or define() fields (Sequelize) that are missing/extra

2. QUERY IMPACT
   - Search the codebase for queries that reference the affected table/columns
   - Check if any existing query would break after the migration
   - Check if new indexes support the existing query patterns

3. MIGRATION ORDERING
   - Check if the migration timestamp conflicts with other migrations in the branch
   - Check if the migration depends on another migration that runs after it
   - For TypeORM: verify the class name matches the file convention

4. FOREIGN KEY ANALYSIS
   - New FKs: verify referenced table/column exists
   - CASCADE rules: are DELETE/UPDATE cascades intentional?
   - Cross-schema references: any references to tables in other services?

Return: model mismatches, query impacts, ordering issues, FK analysis.
```

---

## Phase 2: Large Table Risk Assessment

### Known large tables in LE

| Table                  | Service         | Estimated rows        | Risk threshold           |
| ---------------------- | --------------- | --------------------- | ------------------------ |
| `orders`               | svc-order       | millions              | CRITICAL: any ALTER      |
| `order_items`          | svc-order       | millions              | CRITICAL: any ALTER      |
| `offers`               | svc-experiences | hundreds of thousands | HIGH: ALTER with lock    |
| `offer_packages`       | svc-experiences | hundreds of thousands | HIGH: ALTER with lock    |
| `experiences`          | svc-experiences | tens of thousands     | MEDIUM                   |
| `experience_schedules` | svc-experiences | tens of thousands     | MEDIUM                   |
| `salesforce_connect.*` | svc-ee-offer    | hundreds of thousands | HIGH                     |
| `offer_meta`           | svc-ee-offer    | hundreds of thousands | HIGH (materialized view) |

### PostgreSQL-specific safety rules

| Operation                                           | Safe?       | Notes                                           |
| --------------------------------------------------- | ----------- | ----------------------------------------------- |
| `ADD COLUMN` (nullable, no default)                 | Yes         | No table rewrite                                |
| `ADD COLUMN ... DEFAULT value`                      | Yes (PG11+) | No table rewrite in PG11+                       |
| `DROP COLUMN`                                       | Careful     | Mark as unused first, drop later                |
| `ALTER COLUMN TYPE`                                 | Depends     | May rewrite table, lock                         |
| `ADD NOT NULL`                                      | Careful     | Needs DEFAULT or data backfill first            |
| `CREATE INDEX`                                      | NO          | Locks table. Use `CREATE INDEX CONCURRENTLY`    |
| `CREATE INDEX CONCURRENTLY`                         | Yes         | No lock, but can't run inside transaction       |
| `DROP INDEX`                                        | Careful     | Check query plans first                         |
| `ADD FOREIGN KEY`                                   | Careful     | Validates all existing rows (can be slow)       |
| `ADD FOREIGN KEY NOT VALID` + `VALIDATE CONSTRAINT` | Yes         | Two-step: add without validation, then validate |

### PostGIS-specific checks (svc-experiences, svc-search)

- Spatial columns: must specify SRID (usually 4326)
- Spatial indexes: use `GIST`, not `BTREE`
- Geometry vs Geography: geography is SRID 4326 only, geometry is flexible
- `ST_` functions in queries: verify they match the column type

---

## Phase 3: Transaction Analysis

### When to use a transaction

- Multiple DDL statements that must all succeed or all fail
- Data migration with referential integrity needs

### When NOT to use a transaction

- `CREATE INDEX CONCURRENTLY` (cannot run inside a transaction)
- Very large data migrations (hold locks too long)
- Multiple independent schema changes (split into separate migrations)

Check:

- Is the migration wrapped in a transaction? (TypeORM does this by default)
- Should it be? (based on the operations above)
- If `CREATE INDEX CONCURRENTLY` is used, is the transaction disabled?

For TypeORM:

```typescript
// To disable transaction for a migration:
public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE INDEX CONCURRENTLY ...`);
}
// And set: transaction = false in the migration options
```

---

## Phase 4: Generate Rollback Script

If the migration doesn't have a proper `down()`, generate one:

```
Suggested rollback for migration XXXX-MigrationName:

  // down()
  await queryRunner.query(`ALTER TABLE "table" DROP COLUMN IF EXISTS "column"`);
  await queryRunner.query(`DROP INDEX IF EXISTS "idx_name"`);
```

If the migration has data transformations that can't be reversed, flag it:

```
IRREVERSIBLE: This migration transforms data in [table].[column].
  up(): converts varchar to integer
  down(): CANNOT reliably reverse (data loss)

  Options:
  1. Add a backup column before transform (recommended)
  2. Accept irreversibility (document in PR)
  3. Use a separate data migration with backup
```

---

## Phase 5: Final Report

```markdown
# Migration Validation Report

## Files Analyzed

- [list of migration files with ORM framework]

## Service Details

- Service: [name]
- ORM: [TypeORM/Sequelize/Prisma]
- Dual DB: [yes/no, if svc-experiences, remind to migrate both]
- PostGIS: [yes/no]

## Summary

| Dimension              | Status    | Critical | High | Medium | Low |
| ---------------------- | --------- | -------- | ---- | ------ | --- |
| Rollback               | PASS/FAIL | 0        | 0    | 0      | 0   |
| Backward Compatibility | PASS/FAIL | 0        | 0    | 0      | 0   |
| Performance            | PASS/FAIL | 0        | 0    | 0      | 0   |
| Data Integrity         | PASS/FAIL | 0        | 0    | 0      | 0   |
| Model Consistency      | PASS/FAIL | 0        | 0    | 0      | 0   |
| Transaction Safety     | PASS/FAIL | 0        | 0    | 0      | 0   |

## Findings

SEVERITY | DIMENSION | FILE:LINE | DESCRIPTION | FIX

## Large Table Warnings

[Only if applicable, table name, estimated rows, operation, risk]

## Rollback Plan

[Generated rollback commands or confirmation that down() is correct]

## Verdict

[APPROVED / APPROVED WITH SUGGESTIONS / NEEDS CHANGES]
```

---

## Rules

- NEVER approve a migration without a rollback (or explicit acknowledgment of irreversibility)
- Large table operations (>100k rows): always flag as HIGH risk
- Column removals: always flag as HIGH (require two-phase deploy)
- `CREATE INDEX` without CONCURRENTLY: always flag as CRITICAL
- If unsure about table size, flag it and ask the user
- Report only findings with confidence 80+
- svc-experiences: ALWAYS remind about dual-database migration (dev + spec)
- PostGIS migrations: verify SRID and index type

## Zero-Downtime Migration Recipes

When the migration involves risky operations on large tables, suggest the appropriate zero-downtime recipe:

### Rename Column (3-step)

```
Migration 1: ADD new column (nullable)
Migration 2: Backfill data (batched, UPDATE ... SET new_col = old_col WHERE new_col IS NULL LIMIT 1000)
Migration 3: DROP old column (after all code references updated)
```

Deploy sequence: Migration 1 -> deploy code that writes to BOTH columns -> Migration 2 -> deploy code that reads from new column -> Migration 3

### Change Column Type (4-step)

```
Migration 1: ADD new column with target type
Migration 2: Backfill with type cast (batched)
Migration 3: Swap code to use new column
Migration 4: DROP old column
```

### Blue-Green Schema Change (5-phase)

For the most critical tables (orders, order_items):

```
Phase 1: ADD new structure (table/column) alongside old
Phase 2: Deploy dual-write code (writes to both old and new)
Phase 3: Backfill historical data
Phase 4: Deploy read-from-new code
Phase 5: DROP old structure (separate PR, after validation period)
```

Reference these recipes in findings when applicable. If a migration does a risky operation in a single step, suggest the multi-step recipe as a fix.

---

## Wrap-up

After validation, suggest next step:

```
Migration validated: [VERDICT]
  [N findings: X critical, Y high, Z medium]

  Next: /code-review (branch mode)
```

## Verification (MANDATORY before presenting report)

- [ ] All migration files in the branch identified and read
- [ ] ORM framework detected correctly (TypeORM/Sequelize/Prisma)
- [ ] Each migration has rollback (down()) verified or irreversibility flagged
- [ ] Large table risk list cross-referenced for every affected table
- [ ] CREATE INDEX checked for CONCURRENTLY
- [ ] Backward compatibility assessed (old code works with new schema)
- [ ] Model/entity consistency verified (migration columns match ORM model)
- [ ] Transaction analysis done (CONCURRENTLY not inside transaction)
- [ ] svc-experiences dual-database reminder included (if applicable)
- [ ] PostGIS checks done (SRID, index type) if spatial columns involved

If svc-experiences:

```
Reminder: Run migration on BOTH databases before testing:
  APP_ENV=development yarn migration:run
  APP_ENV=spec yarn migration:run
```
