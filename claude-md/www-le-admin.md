# www-le-admin — Service Dossier

This file provides unified guidance to all AI coding assistants when working with code in this repository.

## Project Overview

This is the **Admin Portal for Luxury Escapes** - a React-based administrative interface for managing the Luxury Escapes travel platform. The portal handles offers, orders, users, vendors, and various business operations across multiple regions.

## Development Commands

### Setup & Installation
```bash
yarn install
cp .env.example .env  # Configure environment variables
```

### Development
```bash
yarn dev              # Start development server (Express + Webpack)
yarn start:dev        # Same as yarn dev
```

### Testing
```bash
yarn test             # Run all tests (lint, types, unit tests)
yarn test:static      # Run linting and type checking only
yarn test-jest        # Run unit tests only
yarn test:watch       # Run tests in watch mode
```

### Code Quality
```bash
yarn test:lint        # Run ESLint and Stylelint
yarn test:lint:fix    # Auto-fix linting issues
yarn test:types       # Run TypeScript type checking
yarn test:types:coverage  # Generate type coverage report
```

### Build & Production
```bash
yarn build            # Build for production
yarn start            # Build and start production server
yarn report           # Generate bundle analyzer report
```

### E2E Testing
```bash
yarn cypress run      # Run Cypress tests headlessly
yarn cypress open     # Open Cypress GUI
```

## Architecture & Technology Stack

### Frontend
- **React 19.0.0** with **TypeScript 4.8.4** (gradual migration from JS)
- **Material-UI v6.5.0** as the primary UI library
- **Redux** with Redux Thunk for state management
- **React Router v5** for routing
- **Styled Components** (being phased out in favor of MUI)
- **TanStack React Query v5.84.1** for server state management

### Build System
- **Webpack 5** with TypeScript configuration
- **Babel** with TypeScript preset
- **Node.js 22.22.1** with **Yarn 1.22.22**

### Development Tools
- **ESLint** with TypeScript, React, and Prettier integration
- **Stylelint** for SCSS linting
- **Jest** with SWC for unit testing
- **React Testing Library**
- **Cypress** for E2E testing

## Code Structure & Patterns

### Directory Structure
```
src/
├── components/         # Feature-based React components
├── services/          # API service layer (50+ services)
├── utils/             # Utility functions and helpers
├── hooks/             # Custom React hooks
├── reducers/          # Redux reducers
├── actions/           # Redux actions
├── types/             # TypeScript type definitions
├── scss/              # SCSS stylesheets
└── configs/           # Theme and configuration
```

### Component Architecture
- Components organized by business domain (Purchases, Offers, Users, etc.)
- Mix of class and functional components (migrating to functional)
- Extensive use of Material-UI components
- Feature-based organization with lazy-loaded routes

### Service Layer
- Comprehensive API service layer with 50+ services
- Consistent error handling patterns
- Type-safe service contracts using `@luxuryescapes/contract-*` packages
- Mock services available for testing

## Development Guidelines

### TypeScript Migration
- **All new features must be written in TypeScript**
- Convert JavaScript files to TypeScript when making significant changes
- Current setting: `"noImplicitAny": false` (gradual migration)

### Component Guidelines
- **Prefer functional components** over class components
- Use **Material-UI components** instead of HTML elements where possible
- New components should be written as regular named functions
- Export only one component as default per file

### Data Fetching Guidelines
- **TanStack Query (React Query) is mandatory for all new data fetching**
- Use `useQuery` for GET requests and data fetching
- Use `useMutation` for POST, PUT, DELETE operations
- Always provide proper query keys for caching
- Handle loading and error states appropriately
- Example pattern:
  ```tsx
  const { data: users = [], isLoading } = useQuery({
    queryKey: ['users', 'search', searchQuery, brand],
    queryFn: async ({ signal }) => {
      return await UsersService.getUsers(
        { filter: searchQuery, brand },
        { signal }
      );
    },
    enabled: !!searchQuery && searchQuery.length >= 2,
  });
  ```

### Styling Guidelines
- **Material-UI (MUI) is the primary design system**
- Avoid custom styling - use MUI's built-in components and theme
- Use `Container maxWidth="xl"` for page content
- Use `Box` for spacing and grouping
- Use `Stack` for alignment and spacing between elements

### Testing Guidelines
- Use **React Testing Library**
- All new tests should use RTL
- Unit tests with Jest, E2E tests with Cypress

### Code Quality Standards
- ESLint rules favor MUI components over HTML elements
- Prettier with custom import ordering
- Function components preferred over class components
- CamelCase naming convention

## Business Domain Areas

The admin portal manages:
- **Offers & Accommodations**: Hotel and travel offer management
- **Purchases & Orders**: Order processing and management
- **Users & Customer Support**: User account and support tools
- **Vendors & Properties**: Vendor relationship management
- **Marketing & Promotions**: Campaign and promotion management
- **Finance & Reporting**: Financial reporting and analytics
- **Tours & Experiences**: Tour package management
- **Cruises**: Cruise offering management
- **Flights**: Flight booking management

## Environment Configuration

### Development Environment
- **Local**: `http://localhost:3000` (Express server on port 3002)
- **Test**: `https://test-admin.luxuryescapes.com`
- **Production**: `https://admin.luxuryescapes.com`
- **Review Apps**: `https://[pr-number].review-luxuryescapes.com`

### Authentication
- Uses Stormpath for authentication (legacy system)
- Google OAuth for review and canary apps (see [docs/google-oauth-review-apps.md](./docs/google-oauth-review-apps.md))
- Permission-based access control with `PermissionedComponent`

## Key Utilities & Helpers

### Common Components
- `PermissionedComponent`: Hide/show based on admin permissions
- `MUIProvider`: Wrap pages to use new Material-UI theme
- `PageLayout`, `PageHeaderBar`, `PageBody`: New page layout pattern
- `TenantSelect`: Multi-tenant switching functionality

### State Management
- Redux store for global application state
- TanStack Query for server state management
- Local storage for tenant selection
- Service layer handles API communication

## Migration Status

### Active Migrations
1. **JavaScript → TypeScript**: Ongoing (new features required in TS)
2. **Class Components → Functional Components**: Gradual modernization
3. **Styled Components → Material-UI**: Design system consolidation
4. **Legacy data fetching → TanStack Query**: New data fetching standard

### Code Quality Requirements
- New code must pass ESLint and TypeScript checks
- All tests must pass before committing
- Use `yarn test` to run full test suite before commits

## Performance Considerations

- Lazy-loaded routes for code splitting
- Bundle analysis available via `yarn report`
- Image optimization and lazy loading implemented
- Material-UI tree-shaking configured

## External Integrations

- **Sentry**: Error tracking and monitoring
- **Datadog**: APM and performance monitoring
- **Google Maps**: Property mapping functionality
- **Stripe**: Payment processing
- **Various APIs**: 50+ microservices for business logic

---

## Code Standards and Recommendations for AI Agents

## **Project Contributing Guidelines**

All code changes must follow the established contributing guidelines:

### **General Requirements**
- TypeScript should be used instead of plain JavaScript
- If significant changes are made to existing JS files, convert them to TypeScript
- Prettier auto-formatting must be enabled or code formatted according to `.prettierrc`
- Use `CamelCase` (Pascal-casing) naming convention

### **React Code Style Requirements**
- File should expose only one component as a default export
- Functional components preferred over class-based components
- Functional components should be created as regular named functions
- New pages go in `src/pages` folder, grouped by functionality or URL path segments
- Reusable components go in `src/components/Common` folder
- General components go in `src/components/Common/Elements` or `src/components/Common/Blocks`

### **Design System Requirements**
- **MUI (https://mui.com) is the mandatory UI library**
- Use `Container` with `maxWidth="xl"` to restrict page content
- Use `Box` for grouping elements or adding margins (mostly top margin)
- Use `Stack` for alignment and spacing between elements
- Use `Dialog` for all modal functionality
- Minimal custom styling with `sx` prop
- Use `components/Common/Elements/PageHeader` for page headers
- Use `components/Common/Elements/PageSubheader` for section headers
- Only `color="primary"` for `Button` unless strict reasons
- Primary buttons: `variant="contained"`, secondary buttons: `variant="text"`
- Button ordering: left-aligned (primary first), right-aligned (secondary first)

### **Data Fetching Requirements**

- **TanStack Query is mandatory for all new data fetching operations**
  - Use `useQuery` for fetching and caching data.
  - Use `useMutation` for data updates (POST, PUT, DELETE).
  - Always provide clear and descriptive query keys to ensure proper caching and avoid cache collisions.
  - Always handle `loading`, `error`, and `success` states as provided by TanStack Query.
  - Use `signal` in your query/mutation functions where supported for request cancellation.
  - Prefer extracting and reusing query/mutation logic via shared hooks when multiple places require the same API access.

- **When working with existing code:**
  - If you need to update or refactor legacy/manual API fetch or mutation logic, **seek user permission first before replacing with TanStack Query**.
  - If you find duplicate or migrated API logic, **ask user for permission to refactor and standardize using shared hooks or queries to eliminate duplication**.

#### TanStack Reusable Hook Architecture
- **Before creating a new hook, always check if a similar API call or reusable hook already exists.** Avoid duplicating logic—reuse existing hooks where possible.
- **ALWAYS create reusable hooks** in `src/hooks/apis/{service}/` - never write `useQuery`/`useMutation` directly in components.
- **One hook file per resource** - separate files for different resources (e.g., `usePropertyDebug.ts`, `useRoomAmenities.ts`).

#### Folder Structure
```
src/hooks/apis/
├── accommodation/
│   ├── usePropertyDebug.ts         # Property debug 
│   └── useRoomAmenities.ts         # Room amenities CRUD
├── notification-proxy/
│   └── useFailedEmails.ts          # Failed emails list &
└── users/
    └── useUserSearch.ts            # User search operations
```

#### Query Keys (Required for each resource)
```tsx
export const amenityQueryKeys = {
  all: ['amenities'] as const,
  lists: () => [...amenityQueryKeys.all, 'list'] as const,
  list: (filters: Filters) => [...amenityQueryKeys.lists(), filters] as const,
  details: () => [...amenityQueryKeys.all, 'detail'] as const,
  detail: (id: string) => [...amenityQueryKeys.details(), id] as const,
};
```

#### Naming Convention
| Operation | Pattern | Example |
|-----------|---------|---------|
| GET list | `useGet{Resource}s` | `useGetAmenities` |
| GET single | `useGet{Resource}` | `useGetAmenity` |
| POST | `useCreate{Resource}` | `useCreateAmenity` |
| PUT/PATCH | `useUpdate{Resource}` | `useUpdateAmenity` |
| DELETE | `useDelete{Resource}` | `useDeleteAmenity` |
| POST (action) | `use{Action}{Resource}` | `useResendFailedEmail` |
---

### 1. **Code Consistency & Naming**

* **Use correct and meaningful class/component names.**
  Avoid typos and ambiguous naming. When importing, use clear import aliases.
  - Prefer descriptive variable names (e.g., `canBeRefunded` instead of `carBeRefunded`)
  - Use intention-revealing names instead of generic terms like `value`/`key`
* **Follow established patterns.**
  Reuse common message or UI blocks and adhere to established component conventions.
* **Stick to DRY (Don't Repeat Yourself).**
  Abstract or reuse helpers/components for repeated logic, especially in forms, lists, or notification blocks.
* **Case Consistency:**
  - Use `camelCase` for variable names, properties, and function names (even when API uses snake_case)
  - Update all internal usages to match the codebase convention

---

### 2. **State Management & Mutability**

* **Immutable State Only.**
  Never mutate Redux state directly. Use immutable operations like `.concat`, spread (`...`), or similar.

  ```js
  // Good
  return { ...state, items: state.items.concat([newItem]) };
  ```
* **Initialize All State Properties.**
  Ensure all state variables and object properties are defined before use. Avoid undefined access.
* **State Management Best Practices:**
  - Use `useState` and `useEffect` for managing component state; avoid using local variables for persistent state
  - Use hooks like `useCallback`, `useMemo` for performance optimization, especially for event handlers or computed values passed to children
  - Use TanStack Query for server state management instead of Redux for API data

---

### 3. **UI/UX Patterns**

* **Use Modern Loading/Error States.**
  - Manage `loading`, `error`, and `success` using TanStack Query's built-in states
  - Provide clear loading indicators (spinners or skeletons) when data is being fetched
  - Avoid deprecated/legacy async components
* **Reset UI on Completion.**
  E.g., after a successful save, revert "Saving..." or "Saved" back to "Save" for clarity.
* **Consistent UI Toggles.**
  Control visibility of sections (expand/collapse) using state variables like `isOpen`. Always sync UI state with logic.
* **Remove Console Logs & Debug Code.**
  No `console.log` or commented-out code in committed code. Clean up before merging. Limited console.error and console.warn calls are allowed if they would add more context when debugging problems
* **Feedback & Accessibility:**
  - Give user feedback for critical actions (save, delete, error, etc.) via snackbars, alerts, or modals
  - Ensure UI updates or reverts button states after actions (e.g., "Save" resets after an edit)
* **Dialog/Modal Confirmations:**
  Always provide confirmation dialogs for destructive actions (e.g., delete), and ensure async handlers use `await` to avoid premature close.

---

### 4. **Form & Data Handling**

* **Centralize Form Field Logic.**
  Use shared methods to decide which fields are enabled/disabled, allowing for easy future changes.
* **Controlled Components:**
  - Use controlled components for form fields
  - Prefer hooks like `useForm`, `Controller` from React Hook Form for better management and validation
  - Use MUI's `required` prop for mandatory fields instead of just asterisks in labels
* **Error Display:**
  - Always provide error messages for invalid form states, with `helperText` for inputs, especially when required
  - Use clear validation rules and types for form data
* **Default Values & Prefilling:**
  - Pre-fill forms with sensible defaults (e.g., today's date, user's data) to reduce user effort
  - If adding new fields, default them to the most likely or current value to support legacy data
* **Prefer Utility Libraries for Data.**
  Use libraries like lodash for operations (`groupBy`, `filter`, `map`) to enhance code readability and avoid mistakes.
* **Explicit Date Handling.**
  Use date libraries (`dayjs`) for all parsing and comparison. Don't rely on implicit type conversion.

---

### 5. **API & Service Layer**

* **No Hardcoded Schema/Fields.**
  Fetch field definitions, schemas, and enums from backend services. Don't duplicate them on the frontend.
* **Constants for API Parameters:**
  - Keep API endpoints, resource names, and frequently-used identifiers in a constants file for easier refactoring and clarity
  - Don't use hardcoded brand names or resource keys; centralize them
* **Centralize Constants.**
  Group related constants (e.g., payment types, status codes, page sizes, offer types) in a single location. Avoid magic strings or inline arrays.
* **Error Handling:**
  - Show clear, user-friendly error messages in snackbars or alerts, optionally including error details for visibility
  - Handle missing or fallback data gracefully without crashing the function
  - Use TanStack Query's error handling capabilities for consistent error management
* **Query Patterns:**
  - Use meaningful query keys that include all dependencies
  - Enable/disable queries based on required data availability
  - Use signal for request cancellation where supported by services

---

### 6. **Testing & Environment**

* **Reuse Helpers in Tests.**
  Use and extend shared helpers for repetitive test steps instead of duplicating logic.
* **Environment-based Configurations.**
  Control test flags (e.g., headless mode) via environment variables, not hardcoded changes.
* **Testing:**
  Where possible, add unit or integration tests for utility functions, especially when handling edge cases or fallback logic.

---

### 7. **Types & Props**

* **Define All PropTypes / Interfaces.**
  All components must declare their props (`PropTypes` or TypeScript interfaces). Remove unused props/imports.
* **Clear Naming.**
  Use singular names for types/entities unless it's a collection (`BookingRequest` vs. `BookingRequests`).
* **Type Safety:**
  - Prefer TypeScript types and interfaces
  - Move large types/interfaces into a typings or types directory for reuse
  - When using generics or complex types inline, consider extracting to a separate definition for readability

---

### 8. **Component Responsibility**

* **Pass Only Needed Props.**
  Do not pass unused or unnecessary props/context into components. Clean up props regularly.
* **Component Modularity:**
  - Move lengthy or reusable functions/components into their own files or utils directory, especially formatter functions, mapping helpers, or input components
  - If logic in renderCell, formatters, or effect hooks gets too complex, extract it to a separate function or component
* **One Component Per File.**
  Avoid multi-component files except for tiny helpers.
* **Use Barrel Exports.**
  Re-export related components via `index.js` for cleaner imports.
* **Acknowledge & Ticket Refactors.**
  When noticing large tech debt or duplication, open a follow-up ticket/PR instead of mixing with unrelated changes.

---

### 9. **Documentation & Schema Use**

* **Respect Schema Restrictions.**
  For forms, build options/enums dynamically from schemas, not from hardcoded arrays.
* **Document Required Fields.**
  Note in code/docs which fields are required or optional and how dynamic options are determined.
* **Code Comments & Docs:**
  - Add inline comments to explain non-obvious logic, especially workarounds, fallbacks, or new default behaviors
  - Document reasons for default values, especially when pre-filling fields (e.g., defaulting to `today`)

---

### 10. **MUI (Material-UI) & Styling Conventions**

#### 10.1 **Component Usage**

* **Always Prefer MUI Components.**
  Use [Material-UI (MUI)](https://mui.com/) for all new UI components, forms, modals, and layouts.
* **No Mixing of Frameworks.**
  Do not mix Bootstrap or custom CSS components with MUI within the same view or flow. Migrate legacy code to MUI where possible.

#### 10.2 **Styling Rules**

* **Leverage Theme and System Props.**
  Use MUI's `theme` object, `sx` prop, and `styled()` API for all customizations.
* **Never Hardcode Colors/Spacing/Fonts.**
  Always use `theme.palette`, `theme.spacing`, and `theme.typography` for consistency and easy theme updates.
* **Component-scoped Styling Only.**
  Use CSS-in-JS (MUI's `styled()`, `sx`)—avoid global or inline CSS except for quick utility use with `sx`.
* **No !important.**
  Never use `!important` unless absolutely necessary and justified in the code review.
* **Extract Shared Attributes:**
  When possible, extract shared column or field attributes (e.g., `sharedAttrs` in MUI DataGrid columns) for DRY code.

#### 10.3 **Forms & Inputs**

* **Use MUI Form Elements.**
  `<TextField>`, `<Checkbox>`, `<Radio>`, and other MUI form controls only.
* **Validation and Feedback.**
  Use MUI's built-in error/validation feedback, not custom or browser-native styles.

#### 10.4 **Modals & Dialogs**

* **Use `<Dialog />` from MUI for all modals.**
* **Structure:** Use `<DialogTitle>`, `<DialogContent>`, `<DialogActions>`.
  Ensure accessibility (ARIA roles/labels) are implemented.

#### 10.5 **Layout & Responsiveness**

* **MUI's Grid System.**
  Use `<Grid container>` and `<Grid item>` for layouts.
* **Responsive Design.**
  Use MUI's breakpoints (`xs`, `sm`, `md`, `lg`) and responsive props.

#### 10.6 **Theme Awareness**

* **All Components Must Be Theme-aware.**
  Ensure custom components respect dark/light themes and palette changes.

#### 10.7 **Examples**

```jsx
// Good: MUI components, theme, and sx
<Box sx={{ p: 2, bgcolor: 'background.paper' }}>
  <Button variant="contained" color="primary">Save</Button>
</Box>

// Good: Styled with MUI theme
import { styled } from '@mui/material/styles';
const MyButton = styled(Button)(({ theme }) => ({
  margin: theme.spacing(1),
  backgroundColor: theme.palette.primary.main,
  '&:hover': { backgroundColor: theme.palette.primary.dark },
}));
```

---

### 11. **Code Quality & Maintenance**

* **Avoid Magic Numbers & Strings:**
  - Extract magic numbers and repeated strings into constants (e.g., API params, roles, types, default values)
  - Use constants for values like `"content-approved"`, `"admin"`, `"universal_search_id"`, or numbers like `2`, `4`, `10`, `50`, etc.
* **Remove Redundant or Dead Code:**
  - Clean up commented or unused code blocks—prefer using version control history if needed
  - If logic or patterns repeat across files, consider creating a shared utility or abstract component

---

### 12. **Migration & Legacy Code**

* **Migrate to MUI When Touching Legacy Files.**
  If you must touch a legacy (Bootstrap/custom) file, migrate it to MUI or ticket it for follow-up.
* **Do Not Add New Bootstrap/Custom CSS.**
  All new UI must use MUI only.
* **Migrate to TanStack Query When Adding Data Fetching.**
  All new data fetching must use TanStack Query instead of Redux or direct service calls.

---

## **Example Patterns**

#### **TanStack Query Data Fetching**

```tsx
import { useQuery, useMutation } from '@tanstack/react-query';

// Fetching data
const { data: users = [], isLoading, error } = useQuery({
  queryKey: ['users', 'search', searchQuery, brand],
  queryFn: async ({ signal }) => {
    return await UsersService.getUsers(
      { filter: searchQuery, brand },
      { signal }
    );
  },
  enabled: !!searchQuery && searchQuery.length >= 2,
});

// Mutating data
const updateUserMutation = useMutation({
  mutationFn: (userData) => UsersService.updateUser(userData),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['users'] });
    enqueueSnackbar('User updated successfully', { variant: 'success' });
  },
  onError: (error) => {
    enqueueSnackbar(`Error updating user: ${error.message}`, { variant: 'error' });
  },
});
```

#### **Loading/Error State**

```tsx
// Using TanStack Query states
if (isLoading) return <CircularProgress />;
if (error) return <Alert severity="error">{error.message}</Alert>;
```

#### **Immutable Redux State Update**

```js
// Correct:
return {
  ...state,
  cartItems: state.cartItems.concat([newItem])
};
```

#### **MUI Dialog Pattern**

```jsx
<Dialog open={open} onClose={handleClose}>
  <DialogTitle>Dialog Title</DialogTitle>
  <DialogContent>
    {/* Content here */}
  </DialogContent>
  <DialogActions>
    <Button onClick={handleClose}>Cancel</Button>
    <Button onClick={handleSave} color="primary">Save</Button>
  </DialogActions>
</Dialog>
```

#### **Constants Organization**

```tsx
// constants/agent.ts
export const AGENT_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
};

export const PAGE_SIZES = [10, 25, 50, 100];

// Usage in component
if (agent.status === AGENT_STATUS.ACTIVE) {
  // ...
}
```

#### **Component Structure Example**

```tsx
import React from 'react';
import { useQuery } from '@tanstack/react-query';

export default function CustomOffersContainer() {
  // props destructuring
  const { ... } = props

  // state vars
  const [loadingState, setLoadingState] = useState<Utils.FetchingState>('idle');

  // queries
  const { data, isLoading } = useQuery({
    queryKey: ['offers'],
    queryFn: () => OffersService.getOffers(),
  });

  // callbacks
  // ...

  // effects
  // ...

  return (
    <Container maxWidth="xl">
      <PageHeader title="Offers" />
      <Box mt={4}>
        {/* Component content goes here */}
      </Box>
    </Container>
  );
}
```

#### **Page Layout Example**

```tsx
import React from 'react';
import { Container, Box, Button, Stack } from '@mui/material';
import { useQuery } from '@tanstack/react-query';

export default function UsersList() {
  const { data: users = [], isLoading } = useQuery({
    queryKey: ['users'],
    queryFn: () => UsersService.getUsers(),
  });

  return (
    <Container maxWidth="xl">
      <PageHeader title="Users">
        <Box>
          <Button variant="contained" color="primary">
            Add user
          </Button>
        </Box>
      </PageHeader>

      <Box mt={4}>
        <form>
          {/* fields here */}

          <Box>
            <Stack direction="row" align="center" spacing={2}>
              <Button variant="contained">Search</Button>
              <Button variant="text">Clear filters</Button>
            </Stack>
          </Box>
        </form>
      </Box>

      <Box mt={4}>
        <DataGrid loading={isLoading} rows={users} />
      </Box>
    </Container>
  );
}
```
