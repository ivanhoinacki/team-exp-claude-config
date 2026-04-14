# Channel & Space Map for Investigation Case

> Parent skill: [../SKILL.md](../SKILL.md)

Complete mapping of Slack channels and Confluence spaces to check during investigations. Organized by tiers (check Tier 1 always, expand as needed).

---

## Slack Priority Channels

### Tier 1: Team & Core (ALWAYS check)

| Channel | ID | Purpose |
|---|---|---|
| `#team-experiences-pt-br` | `C036ALHDG79` | Team internal (PT-BR), sprint goals, priorities |
| `#svc-experiences` | `C0344V8000M` | svc-experiences service discussions |
| `#svc-ee-offer` | `C06CQ53CKEE` | svc-ee-offer / LED service discussions |
| `#007-exp` | `C04N4941MDE` | Bug reports related to experiences ONLY |
| `#experience-failed-bookings` | `C063YC78ZGC` | Failed booking alerts |
| `#experiences-alerts` | `C04LRU3RNH5` | Production alerts for experiences |
| `#experiences-issues-manual-intervention` | `C06U7SCH0EA` | Manual intervention needed for experience issues |
| `#experiences-jira-alerts` | `C0907N90YG1` | Jira ticket alerts for experiences |
| `#societe-experiences_carhire` | `C08BDGHRHFV` | Experiences + car hire squad (Societe program) |

### Tier 2: Adjacent Teams & Services (check when service chain crosses teams)

| Channel | ID | Purpose |
|---|---|---|
| `#team-customer-payments` | `C01SXP59LGG` | svc-order, checkout, refunds, promos |
| `#team-bundles` | `C09CKS61ARY` | Bundle/complimentary features, cross-vertical packaging |
| `#svc-order` | `CFKU42FD4` | svc-order service (owned by payments team) |
| `#svc-promo` | `CG0HDQ162` | Promo service errors and discussions |
| `#svc-traveller` | `CFY31PLEP` | Traveller forms, checkout data |
| `#svc-search` | `C01930V1GPL` | Search service (indexes experience offers) |
| `#svc-cart` | `C025TK1JQCU` | Cart service |
| `#svc-sailthru` | `CFJ9Z5HHA` | Email dispatch service |
| `#svc-notification-proxy` | `C01N7B5DCF9` | Email orchestration proxy |
| `#svc-vendor` | `C05QFLM814G` | Vendor management service |
| `#admin-portal` | `CFJGFLBNW` | www-le-admin discussions |
| `#team-tours` | `C01QBPJ7MTJ` | Tours team (adjacent vertical) |

### Tier 3: Provider Integrations (check when investigating provider-specific issues)

| Channel | ID | Purpose |
|---|---|---|
| `#klook-integration-external` | `C097FPR77SB` | Klook provider integration (external) |
| `#klook-sales` | `C09NA4YCEE6` | Klook sales data |
| `#collinson-integration-internal` | `C09R8BLUWMT` | Collinson/lounge integration |
| `#south-sea-integration-internal` | `C0AF41S6U15` | South Sea Cruises / CustomLinc |
| `#exp-rezdy-new-ticket-alerts` | `C066L3Q61E2` | Rezdy new ticket alerts |
| `#svc-connection-derbysoft` | `C02JPV6C0T0` | Derbysoft connection service |
| `#svc-addons` | `CLCF57YRE` | Addons service (legacy Rezdy integration) |

### Tier 4: Cross-Functional (check for broad context, incidents, escalations)

| Channel | ID | Purpose |
|---|---|---|
| `#engineering` | `CFCM987JS` | Cross-team engineering discussions |
| `#support` | `C01B1HZDZ7Z` | On-call, incidents, support roster |
| `#helpdesk` | `C09PZ49NQL9` | IT helpdesk, access issues |
| `#team-data` | `C02R107KJBZ` | Data platform, BigQuery |
| `#experiences-ux` | `C03FQHFGEPL` | Experiences UX discussions |
| `#report-bug007` | `C06PT0M46BY` | Bug reporting channel |
| `#whitelabels-incidents` | `C08MH7LL333` | Whitelabel incidents |

### Tier Selection Guide

Select tiers based on the problem domain: Tier 1 always, Tier 2 when crossing service boundaries, Tier 3 for provider issues, Tier 4 for broad context.

---

## Confluence Spaces

### Tier 1: Primary (ALWAYS search)

| Space | Key | Content relevant to Experiences |
|---|---|---|
| **PE** | Product & Engineering | Features, specs, ADRs, bug docs, provider integrations, roadmap, bundle docs |
| **TEC** | Technical | Architecture diagrams, engineering roadmap, postmortems, provider patterns, ADRs |
| **ENGX** | Engineering Excellence | CLI docs, infra, deploy processes, service cutover checklists |

### Tier 2: Cross-Team (search when issue crosses team boundaries)

| Space | Key | Content relevant to Experiences |
|---|---|---|
| **OE** | Operations Excellence | Complimentary refunds SPIKE, addon->experience migration, promo calc issues, airport transfers |
| **HOT** | Hotels | Bundle pricing model, margin burn, tag-based bundles, hotel+experience packaging |
| **WHI** | White Labels | LED experiences, svc-ee-offer dependencies, Heroku shutdown plan, BNBL emails |
| **LOYAL** | Loyalty/Societe | LuxPlus+ experiences pricing, margin calculations for bundles, Societe roadmap |
| **TOUR** | Tours | Optional experiences post-purchase, experience reservations in svc-order |

### Tier 3: Adjacent (search for broader context)

| Space | Key | Content relevant to Experiences |
|---|---|---|
| **GX** | Growth/Experience | Experiences upsell in booking flow, native mobile upsell, LuxPlus+ carousel |
| **BMP** | Brand/Marketing Platform | Upsell emails, post-purchase journeys, audience segmentation |
| **PROD** | Product | Experiences glossary, feed integrations |
| **SO** | Sales Operations | Bundled experiences troubleshooting guide, flash hotels checklist |
| **DH** | Destination Hosting | Optional experiences for charter tours, Journey Beyond process |
| **CS** | Customer Support | Customer-facing issues, escalation processes |
| **DATA** | Data | BigQuery, analytics, reporting pipelines |

### Space Search Rule

Never search only one space. A feature may have its spec in PE, its ADR in TEC, its migration in OE, its pricing in LOYAL, its bundle rules in HOT, and its troubleshooting guide in SO. Always search Tier 1 completely, then expand to Tier 2/3 based on the problem domain.
