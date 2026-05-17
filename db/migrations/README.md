# Database Migrations

Flyway versioned SQL files applied to RDS MySQL at deployment time.

The SQL files are packaged into an immutable Docker image from this directory
and deployed by the `helm/db-migrations` ArgoCD application. Do not duplicate
SQL inside Helm templates; add new migrations here and let the
`Build DB Migration Image` workflow promote the image tag through
`helm/db-migrations/values-staging.yaml`.

## Files
- V1__customers_schema.sql — owners and pets tables
- V2__customers_data.sql — seed data for owners and pets
- V3__vets_schema.sql — vets and specialties tables
- V4__vets_data.sql — seed data for vets
- V5__visits_schema.sql — visits table
- V6__visits_data.sql — seed data for visits
