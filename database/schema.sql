
-- Lunar Resource Optimizer
-- Initial SQLite schema
-- Schema version: 1
-- This file defines structure only; it does not contain NASA observations.

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- 1. Scientific data sources
CREATE TABLE IF NOT EXISTS data_sources (
    source_id       INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    provider        TEXT NOT NULL,
    url             TEXT,
    description     TEXT,
    license         TEXT,
    source_type     TEXT NOT NULL DEFAULT 'scientific'
                    CHECK (source_type IN (
                        'scientific', 'documentation', 'assumption'
                    )),
    created_at      TEXT NOT NULL DEFAULT
                    (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (provider, name)
);

-- 2. Downloaded files and source versions
CREATE TABLE IF NOT EXISTS data_versions (
    version_id      INTEGER PRIMARY KEY,
    source_id       INTEGER NOT NULL,
    version_label   TEXT,
    downloaded_at   TEXT,
    file_path       TEXT,
    sha256          TEXT,
    data_status     TEXT NOT NULL DEFAULT 'raw'
                    CHECK (data_status IN (
                        'raw', 'validated', 'rejected'
                    )),
    notes           TEXT,
    created_at      TEXT NOT NULL DEFAULT
                    (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    FOREIGN KEY (source_id)
        REFERENCES data_sources(source_id)
        ON DELETE RESTRICT,
    CHECK (sha256 IS NULL OR length(sha256) = 64)
);

-- 3. Candidate lunar regions
CREATE TABLE IF NOT EXISTS regions (
    region_id       INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    latitude        REAL NOT NULL
                    CHECK (latitude BETWEEN -90.0 AND 90.0),
    longitude       REAL NOT NULL
                    CHECK (longitude BETWEEN -180.0 AND 180.0),
    elevation_m     REAL,
    slope_deg       REAL
                    CHECK (slope_deg IS NULL OR
                           slope_deg BETWEEN 0.0 AND 180.0),
    geometry_ref    TEXT,
    description     TEXT,
    created_at      TEXT NOT NULL DEFAULT
                    (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- 4. Evaluation criteria
CREATE TABLE IF NOT EXISTS criteria (
    criterion_id    INTEGER PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    description     TEXT,
    unit            TEXT,
    weight          REAL NOT NULL DEFAULT 0.0
                    CHECK (weight BETWEEN 0.0 AND 1.0),
    scoring_method  TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1
                    CHECK (is_active IN (0, 1)),
    created_at      TEXT NOT NULL DEFAULT
                    (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- 5. Scientific measurements
CREATE TABLE IF NOT EXISTS measurements (
    measurement_id      INTEGER PRIMARY KEY,
    region_id           INTEGER,
    version_id          INTEGER NOT NULL,
    criterion_id        INTEGER,
    variable_name       TEXT NOT NULL,
    value               REAL,
    unit                TEXT,
    latitude            REAL
                        CHECK (latitude IS NULL OR
                               latitude BETWEEN -90.0 AND 90.0),
    longitude           REAL
                        CHECK (longitude IS NULL OR
                               longitude BETWEEN -180.0 AND 180.0),
    observed_at         TEXT,
    spatial_resolution_m REAL
                        CHECK (spatial_resolution_m IS NULL OR
                               spatial_resolution_m >= 0.0),
    confidence          REAL
                        CHECK (confidence IS NULL OR
                               confidence BETWEEN 0.0 AND 1.0),
    quality_status      TEXT NOT NULL DEFAULT 'pending'
                        CHECK (quality_status IN (
                            'pending', 'valid', 'warning', 'invalid'
                        )),
    record_class        TEXT NOT NULL DEFAULT 'unverified'
                        CHECK (record_class IN (
                            'real', 'synthetic', 'unverified'
                        )),
    provenance          TEXT,
    created_at          TEXT NOT NULL DEFAULT
                        (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY (region_id)
        REFERENCES regions(region_id)
        ON DELETE RESTRICT,

    FOREIGN KEY (version_id)
        REFERENCES data_versions(version_id)
        ON DELETE RESTRICT,

    FOREIGN KEY (criterion_id)
        REFERENCES criteria(criterion_id)
        ON DELETE RESTRICT,

    CHECK (
        (latitude IS NULL AND longitude IS NULL)
        OR
        (latitude IS NOT NULL AND longitude IS NOT NULL)
    )
);

-- 6. Reproducible region scoring results
CREATE TABLE IF NOT EXISTS region_scores (
    score_id        INTEGER PRIMARY KEY,
    region_id       INTEGER NOT NULL,
    criterion_id    INTEGER NOT NULL,
    model_version   TEXT NOT NULL,
    score           REAL
                    CHECK (score IS NULL OR score BETWEEN 0.0 AND 100.0),
    weight_used     REAL NOT NULL
                    CHECK (weight_used BETWEEN 0.0 AND 1.0),
    input_summary   TEXT,
    calculated_at   TEXT NOT NULL DEFAULT
                    (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY (region_id)
        REFERENCES regions(region_id)
        ON DELETE RESTRICT,

    FOREIGN KEY (criterion_id)
        REFERENCES criteria(criterion_id)
        ON DELETE RESTRICT,

    UNIQUE (region_id, criterion_id, model_version)
);

-- 7. Data validation audit trail
CREATE TABLE IF NOT EXISTS validation_results (
    validation_id   INTEGER PRIMARY KEY,
    version_id      INTEGER NOT NULL,
    measurement_id  INTEGER,
    check_name      TEXT NOT NULL,
    status          TEXT NOT NULL
                    CHECK (status IN ('pass', 'warning', 'fail')),
    message         TEXT,
    checked_at      TEXT NOT NULL DEFAULT
                    (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY (version_id)
        REFERENCES data_versions(version_id)
        ON DELETE RESTRICT,

    FOREIGN KEY (measurement_id)
        REFERENCES measurements(measurement_id)
        ON DELETE RESTRICT
);

-- 8. Explicit assumptions used by the model
CREATE TABLE IF NOT EXISTS assumptions (
    assumption_id   INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    value           TEXT NOT NULL,
    unit            TEXT,
    description     TEXT,
    source_id       INTEGER,
    status          TEXT NOT NULL DEFAULT 'proposed'
                    CHECK (status IN (
                        'proposed', 'reviewed', 'approved'
                    )),
    model_version   TEXT,
    created_at      TEXT NOT NULL DEFAULT
                    (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY (source_id)
        REFERENCES data_sources(source_id)
        ON DELETE RESTRICT
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_versions_source
    ON data_versions(source_id);

CREATE INDEX IF NOT EXISTS idx_measurements_region
    ON measurements(region_id);

CREATE INDEX IF NOT EXISTS idx_measurements_version
    ON measurements(version_id);

CREATE INDEX IF NOT EXISTS idx_measurements_criterion
    ON measurements(criterion_id);

CREATE INDEX IF NOT EXISTS idx_measurements_variable
    ON measurements(variable_name);

CREATE INDEX IF NOT EXISTS idx_measurements_quality
    ON measurements(quality_status, record_class);

CREATE INDEX IF NOT EXISTS idx_scores_region
    ON region_scores(region_id, model_version);

CREATE INDEX IF NOT EXISTS idx_validation_version
    ON validation_results(version_id);

CREATE INDEX IF NOT EXISTS idx_assumptions_status
    ON assumptions(status);

PRAGMA user_version = 1;

COMMIT;
