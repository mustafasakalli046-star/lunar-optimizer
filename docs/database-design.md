# Lunar Resource Optimizer — Database Design

## 1. Purpose
This SQLite database stores lunar resource data, candidate regions,
measurements, scoring results, validation records, and project assumptions.

## 2. Database
- Engine: SQLite
- Schema version: 1
- Schema file: database/schema.sql
- Initial migration: database/migrations/001_initial_schema.sql
- Database file: database/lunar_optimizer.db

## 3. Tables
| Table | Purpose |
|---|---|
| data_sources | Records data providers and source information |
| data_versions | Tracks downloaded dataset versions and file hashes |
| regions | Stores candidate lunar regions and geographic properties |
| criteria | Defines evaluation criteria, weights, and scoring methods |
| measurements | Stores measurements linked to regions, criteria, and data versions |
| region_scores | Stores calculated region scores |
| validation_results | Records data quality and validation checks |
| assumptions | Stores project assumptions and their review status |

## 4. Data Classification
Measurements use record_class to distinguish:
- real: obtained from a real data source
- synthetic: generated for testing or demonstration
- unverified: not yet adequately verified

Synthetic or unverified data must not be presented as confirmed lunar observations.

## 5. Data Quality
Measurements have a quality_status. Validation results record checks
and their outcomes. Dataset provenance should be preserved wherever possible.

## 6. Integrity
- Foreign keys connect related records.
- Geographic coordinates and score ranges are constrained.
- Confidence values must remain within their allowed range.
- Indexes support common lookups.

## 7. Important Limitation
The schema is an initial design. Before importing NASA datasets,
inspect their actual formats, units, coordinate systems, spatial resolutions,
licensing, and metadata. Add or adjust fields when justified by real data.

## 8. Current Verification
- Eight tables created.
- Foreign-key integrity check passed.
- Invalid latitude rejected.
- Invalid foreign-key reference rejected.
- Invalid confidence value rejected.
- Synthetic measurement classification tested.
