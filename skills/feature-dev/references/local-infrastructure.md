# Local Infrastructure

Derive supporting services and ports from the target repository compose files, manifests and README.
The default checkout root is `__CODEBASE_ROOT__`; the project context overrides this value.
Before integration tests, confirm the required service is listening and its data/environment match the test.
Start only project-approved local services. Do not recreate unrelated infrastructure.
A connection failure is evidence to investigate, not permission to change environments or credentials.
New infrastructure dependencies require the user-approved implementation scope.
