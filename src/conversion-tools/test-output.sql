CREATE TABLE rds.dim_k12_schools (
    dim_k12_school_id SERIAL NOT NULL,
    lea_organization_name VARCHAR(1000),
    lea_identifier_nces VARCHAR(50),
    lea_identifier_sea VARCHAR(50),
    name_of_institution VARCHAR(1000),
    school_identifier_nces VARCHAR(50),
    school_identifier_sea VARCHAR(50),
    sea_organization_name VARCHAR(1000),
    sea_organization_identifier_sea VARCHAR(50),
    state_ansi_code VARCHAR(10),
    state_abbreviation_code VARCHAR(10),
    state_abbreviation_description VARCHAR(1000),
    prior_lea_identifier_sea VARCHAR(50),
    prior_school_identifier_sea VARCHAR(50),
    charter_school_indicator BOOLEAN,
    charter_school_contract_id_number TEXT,
    charter_school_contract_approval_date TEXT,
    charter_school_contract_renewal_date TEXT,
    reported_federally BOOLEAN,
    lea_type_code VARCHAR(50),
    lea_type_description VARCHAR(100),
    lea_type_ed_facts_code VARCHAR(50),
    school_type_code VARCHAR(50),
    school_type_description VARCHAR(100),
    school_type_ed_facts_code VARCHAR(50),
    mailing_address_city VARCHAR(30),
    mailing_address_postal_code VARCHAR(17),
    mailing_address_state_abbreviation VARCHAR(50),
    mailing_address_street_number_and_name VARCHAR(40),
    physical_address_city VARCHAR(30),
    physical_address_postal_code VARCHAR(17),
    physical_address_state_abbreviation VARCHAR(50),
    physical_address_street_number_and_name VARCHAR(40),
    telephone_number VARCHAR(24),
    web_site_address VARCHAR(300),
    out_of_state_indicator BOOLEAN,
    record_start_date_time TIMESTAMP,
    record_end_date_time TIMESTAMP,
    school_operational_status VARCHAR (50),
    school_operational_status_ed_facts_code INTEGER,
    charter_school_status VARCHAR (50),
    reconstituted_status VARCHAR (50),
    mailing_address_apartment_room_or_suite_number VARCHAR (40),
    physical_address_apartment_room_or_suite_number VARCHAR (40),
    ieu_organization_name VARCHAR(1000),
    ieu_organization_identifier_sea VARCHAR(50),
    mailing_address_county_ansi_code_code CHAR (5),
    physical_address_county_ansi_code_code CHAR (5),
    longitude VARCHAR (20),
    latitude VARCHAR (20),
    school_operational_status_effective_date TIMESTAMP,
    administrative_funding_control_code VARCHAR(50),
    administrative_funding_control_description VARCHAR(200),
    CONSTRAINT pk__dim_k12_schools PRIMARY KEY (dim_k12_school_id)
);

CREATE INDEX idx__dim_schools__state_ansi_code ON rds.dim_k12_schools (state_ansi_code] asc);

CREATE INDEX idx__dim_k12_schools__school_identifier_sea ON rds.dim_k12_schools (school_identifier_sea] asc);

CREATE INDEX idx__dim_k12_schools__record_start_date_time ON rds.dim_k12_schools (record_start_date_time] asc, school_identifier_sea, record_end_date_time);

CREATE INDEX idx__dim_schools__state_abbreviation_code ON rds.dim_k12_schools (state_abbreviation_code] asc);

CREATE INDEX idx__dim_k12_schools__school_identifier_sea__dim_k12_school_id__record_start_date_time__record_end_date_time ON rds.dim_k12_schools (school_identifier_sea] asc, dim_k12_school_id] asc, record_start_date_time] asc, record_end_date_time] asc, school_operational_status);

CREATE INDEX idx__dim_k12_schools__school_identifier_sea__record_start_date_time ON rds.dim_k12_schools (school_identifier_sea] asc, record_start_date_time] asc, record_end_date_time);

COMMENT ON TABLE rds.dim_k12_schools IS 'Converted from SQL Server table [RDS].[DimK12Schools]';