CREATE TABLE rds.fact_k12_student_enrollments (
    fact_k12_student_enrollment_id BIGSERIAL NOT NULL,
    school_year_id INTEGER DEFAULT -1,
    count_date_id INTEGER DEFAULT -1,
    data_collection_id INTEGER DEFAULT -1,
    sea_id INTEGER DEFAULT -1,
    ieu_id INTEGER DEFAULT -1,
    k12_student_id BIGINTEGER DEFAULT -1,
    lea_accountability_id INTEGER DEFAULT -1,
    lea_attendance_id INTEGER DEFAULT -1,
    lea_funding_id INTEGER DEFAULT -1,
    lea_graduation_id INTEGER DEFAULT -1,
    lea_individualized_education_program_id INTEGER DEFAULT -1,
    k12_school_id INTEGER DEFAULT -1,
    education_organization_network_id INTEGER DEFAULT -1,
    cohort_graduation_year_id INTEGER DEFAULT -1,
    cohort_year_id INTEGER DEFAULT -1,
    cte_status_id INTEGER DEFAULT -1,
    entry_grade_level_id INTEGER DEFAULT -1,
    exit_grade_level_id INTEGER DEFAULT -1,
    enrollment_entry_date_id INTEGER DEFAULT -1,
    enrollment_exit_date_id INTEGER DEFAULT -1,
    english_learner_status_id INTEGER DEFAULT -1,
    k12_enrollment_status_id INTEGER DEFAULT -1,
    k12_demographic_id INTEGER DEFAULT -1,
    idea_status_id INTEGER DEFAULT -1,
    homelessness_status_id INTEGER DEFAULT -1,
    economically_disadvantaged_status_id INTEGER DEFAULT -1,
    foster_care_status_id INTEGER DEFAULT -1,
    immigrant_status_id INTEGER DEFAULT -1,
    language_home_id INTEGER DEFAULT -1,
    language_native_id INTEGER DEFAULT -1,
    migrant_status_id INTEGER DEFAULT -1,
    military_status_id INTEGER DEFAULT -1,
    n_or_d_status_id INTEGER DEFAULT -1,
    primary_disability_type_id INTEGER DEFAULT -1,
    secondary_disability_type_id INTEGER DEFAULT -1,
    projected_graduation_date_id INTEGER DEFAULT -1,
    status_start_date_economically_disadvantaged_id INTEGER DEFAULT -1,
    status_end_date_economically_disadvantaged_id INTEGER DEFAULT -1,
    status_start_date_english_learner_id INTEGER DEFAULT -1,
    status_end_date_english_learner_id INTEGER DEFAULT -1,
    status_start_date_homelessness_id INTEGER DEFAULT -1,
    status_end_date_homelessness_id INTEGER DEFAULT -1,
    status_start_date_idea_id INTEGER DEFAULT -1,
    status_end_date_idea_id INTEGER DEFAULT -1,
    status_start_date_migrant_id INTEGER DEFAULT -1,
    status_end_date_migrant_id INTEGER DEFAULT -1,
    status_start_date_military_connected_student_id INTEGER DEFAULT -1,
    status_end_date_military_connected_student_id INTEGER DEFAULT -1,
    status_start_date_perkins_english_learner_id INTEGER DEFAULT -1,
    status_end_date_perkins_english_learner_id INTEGER DEFAULT -1,
    status_end_date_title_iii_immigrant_id INTEGER DEFAULT -1,
    status_start_date_title_iii_immigrant_id INTEGER DEFAULT -1,
    title_iii_status_id INTEGER DEFAULT -1,
    full_time_equivalency DECIMAL (5, 2),
    student_count INTEGER NOT NULL,
    responsible_school_type_id INTEGER DEFAULT -1,
    lea_membership_resident_id INTEGER DEFAULT -1,
    CONSTRAINT [PK_FactK12StudentEnrollments] PRIMARY KEY NONCLUSTERED ([FactK12StudentEnrollmentId] ASC),
    CONSTRAINT fk__fact_k12_student_enrollments__cohort_graduation_year_id FOREIGN KEY (cohort_graduation_year_id) REFERENCES rds.dim_school_years (dim_school_year_id),
    CONSTRAINT fk__fact_k12_student_enrollments__cohort_year_id FOREIGN KEY (cohort_year_id) REFERENCES rds.dim_school_years (dim_school_year_id),
    CONSTRAINT fk__fact_k12_student_enrollments__count_date_id FOREIGN KEY (count_date_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__cte_status_id FOREIGN KEY (cte_status_id) REFERENCES rds.dim_cte_statuses (dim_cte_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__data_collection_id FOREIGN KEY (data_collection_id) REFERENCES rds.dim_data_collections (dim_data_collection_id),
    CONSTRAINT fk__fact_k12_student_enrollments__economically_disadvantaged_status_id FOREIGN KEY (economically_disadvantaged_status_id) REFERENCES rds.dim_economically_disadvantaged_statuses (dim_economically_disadvantaged_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__education_organization_network_id FOREIGN KEY (education_organization_network_id) REFERENCES rds.dim_education_organization_networks (dim_education_organization_network_id),
    CONSTRAINT fk__fact_k12_student_enrollments__english_learner_status_id FOREIGN KEY (english_learner_status_id) REFERENCES rds.dim_english_learner_statuses (dim_english_learner_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__enrollment_entry_date_id FOREIGN KEY (enrollment_entry_date_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__enrollment_exit_date_id FOREIGN KEY (enrollment_exit_date_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__entry_grade_level_id FOREIGN KEY (entry_grade_level_id) REFERENCES rds.dim_grade_levels (dim_grade_level_id),
    CONSTRAINT fk__fact_k12_student_enrollments__exit_grade_level_id FOREIGN KEY (exit_grade_level_id) REFERENCES rds.dim_grade_levels (dim_grade_level_id),
    CONSTRAINT fk__fact_k12_student_enrollments__foster_care_status_id FOREIGN KEY (foster_care_status_id) REFERENCES rds.dim_foster_care_statuses (dim_foster_care_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__graduation_lea_id FOREIGN KEY (lea_graduation_id) REFERENCES rds.dim_leas (dim_lea_id),
    CONSTRAINT fk__fact_k12_student_enrollments__homelessness_status_end_date_id FOREIGN KEY (status_end_date_homelessness_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__homelessness_status_id FOREIGN KEY (homelessness_status_id) REFERENCES rds.dim_homelessness_statuses (dim_homelessness_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__homelessness_status_start_date_id FOREIGN KEY (status_start_date_homelessness_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__idea_status_id FOREIGN KEY (idea_status_id) REFERENCES rds.dim_idea_statuses (dim_idea_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__ieu_id FOREIGN KEY (ieu_id) REFERENCES rds.dim_ieus (dim_ieu_id),
    CONSTRAINT fk__fact_k12_student_enrollments__immigrant_status_id FOREIGN KEY (immigrant_status_id) REFERENCES rds.dim_immigrant_statuses (dim_immigrant_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments_k12_demographic_id FOREIGN KEY (k12_demographic_id) REFERENCES rds.dim_k12_demographics (dim_k12_demographic_id),
    CONSTRAINT fk__fact_k12_student_enrollments_k12_enrollment_status_id FOREIGN KEY (k12_enrollment_status_id) REFERENCES rds.dim_k12_enrollment_statuses (dim_k12_enrollment_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments_k12_school_id FOREIGN KEY (k12_school_id) REFERENCES rds.dim_k12_schools (dim_k12_school_id),
    CONSTRAINT fk__fact_k12_student_enrollments_k12_student_id FOREIGN KEY (k12_student_id) REFERENCES rds.dim_people (dim_person_id),
    CONSTRAINT fk__fact_k12_student_enrollments__language_home_id FOREIGN KEY (language_home_id) REFERENCES rds.dim_languages (dim_language_id),
    CONSTRAINT fk__fact_k12_student_enrollments__language_native_id FOREIGN KEY (language_native_id) REFERENCES rds.dim_languages (dim_language_id),
    CONSTRAINT fk__fact_k12_student_enrollments__lea_accountability_id FOREIGN KEY (lea_accountability_id) REFERENCES rds.dim_leas (dim_lea_id),
    CONSTRAINT fk__fact_k12_student_enrollments__lea_attendance_id FOREIGN KEY (lea_attendance_id) REFERENCES rds.dim_leas (dim_lea_id),
    CONSTRAINT fk__fact_k12_student_enrollments__lea_funding_id FOREIGN KEY (lea_funding_id) REFERENCES rds.dim_leas (dim_lea_id),
    CONSTRAINT fk__fact_k12_student_enrollments__lea_individualized_education_program_id FOREIGN KEY (lea_individualized_education_program_id) REFERENCES rds.dim_leas (dim_lea_id),
    CONSTRAINT fk__fact_k12_student_enrollments__lea_membership_resident_id FOREIGN KEY (lea_membership_resident_id) REFERENCES rds.dim_leas (dim_lea_id),
    CONSTRAINT fk__fact_k12_student_enrollments__migrant_status_id FOREIGN KEY (migrant_status_id) REFERENCES rds.dim_migrant_statuses (dim_migrant_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__military_status_id FOREIGN KEY (military_status_id) REFERENCES rds.dim_military_statuses (dim_military_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments_n_or_d_status_id FOREIGN KEY (n_or_d_status_id) REFERENCES rds.dim_n_or_d_statuses (dim_n_or_d_status_id),
    CONSTRAINT fk__fact_k12_student_enrollments__primary_disability_type_id FOREIGN KEY (primary_disability_type_id) REFERENCES rds.dim_idea_disability_types (dim_idea_disability_type_id),
    CONSTRAINT fk__fact_k12_student_enrollments__projected_graduation_date_id FOREIGN KEY (projected_graduation_date_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__responsible_school_type_id FOREIGN KEY (responsible_school_type_id) REFERENCES rds.dim_responsible_school_types (dim_responsible_school_type_id),
    CONSTRAINT fk__fact_k12_student_enrollments__school_year_id FOREIGN KEY (school_year_id) REFERENCES rds.dim_school_years (dim_school_year_id),
    CONSTRAINT fk__fact_k12_student_enrollments__sea_id FOREIGN KEY (sea_id) REFERENCES rds.dim_seas (dim_sea_id),
    CONSTRAINT fk__fact_k12_student_enrollments__secondary_disability_type_id FOREIGN KEY (secondary_disability_type_id) REFERENCES rds.dim_idea_disability_types (dim_idea_disability_type_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_end_date_economically_disadvantaged_id FOREIGN KEY (status_end_date_economically_disadvantaged_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_end_date_english_learner_id FOREIGN KEY (status_end_date_english_learner_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_end_date_idea_id FOREIGN KEY (status_end_date_idea_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_end_date_migrant_id FOREIGN KEY (status_end_date_migrant_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_end_date_military_connected_student_id  FOREIGN KEY (status_end_date_military_connected_student_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_end_date_perkins_english_learner_id FOREIGN KEY (status_end_date_perkins_english_learner_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_end_date_title_iii_immigrant_id FOREIGN KEY (status_end_date_title_iii_immigrant_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_start_date_economically_disadvantaged_id FOREIGN KEY (status_start_date_economically_disadvantaged_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_start_date_english_learner_id FOREIGN KEY (status_start_date_english_learner_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_start_date_idea_id FOREIGN KEY (status_start_date_idea_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_start_date_migrant_id FOREIGN KEY (status_start_date_migrant_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_start_date_military_connected_student_id FOREIGN KEY (status_start_date_military_connected_student_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_start_date_perkins_english_learner_id FOREIGN KEY (status_start_date_perkins_english_learner_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__status_start_date_title_iii_immigrant_id FOREIGN KEY (status_start_date_title_iii_immigrant_id) REFERENCES rds.dim_dates (dim_date_id),
    CONSTRAINT fk__fact_k12_student_enrollments__title_iii_status_id FOREIGN KEY (title_iii_status_id) REFERENCES rds.dim_title_iii_statuses (dim_title_iii_status_id)
);

CREATE INDEX ixfk__fact_k12_student_enrollments__school_year_id ON rds.fact_k12_student_enrollments (school_year_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__count_date_id ON rds.fact_k12_student_enrollments (count_date_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__data_collection_id ON rds.fact_k12_student_enrollments (data_collection_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__sea_id ON rds.fact_k12_student_enrollments (sea_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__ieu_id ON rds.fact_k12_student_enrollments (ieu_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments_k12_student_id ON rds.fact_k12_student_enrollments (k12_student_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__lea_accountability_id ON rds.fact_k12_student_enrollments (lea_accountability_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__lea_attendance_id ON rds.fact_k12_student_enrollments (lea_attendance_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__lea_funding_id ON rds.fact_k12_student_enrollments (lea_funding_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__lea_graduation_id ON rds.fact_k12_student_enrollments (lea_graduation_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__lea_individualized_education_program_id ON rds.fact_k12_student_enrollments (lea_individualized_education_program_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments_k12_school_id ON rds.fact_k12_student_enrollments (k12_school_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__education_organization_network_id ON rds.fact_k12_student_enrollments (education_organization_network_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__cohort_graduation_year_id ON rds.fact_k12_student_enrollments (cohort_graduation_year_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__cohort_year_id ON rds.fact_k12_student_enrollments (cohort_year_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__cte_status_id ON rds.fact_k12_student_enrollments (cte_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__entry_grade_level_id ON rds.fact_k12_student_enrollments (entry_grade_level_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__exit_grade_level_id ON rds.fact_k12_student_enrollments (exit_grade_level_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__enrollment_entry_date_id ON rds.fact_k12_student_enrollments (enrollment_entry_date_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__enrollment_exit_date_id ON rds.fact_k12_student_enrollments (enrollment_exit_date_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__english_learner_status_id ON rds.fact_k12_student_enrollments (english_learner_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments_k12_enrollment_status_id ON rds.fact_k12_student_enrollments (k12_enrollment_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments_k12_demographic_id ON rds.fact_k12_student_enrollments (k12_demographic_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__idea_status_id ON rds.fact_k12_student_enrollments (idea_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__homelessness_status_id ON rds.fact_k12_student_enrollments (homelessness_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__economically_disadvantaged_status_id ON rds.fact_k12_student_enrollments (economically_disadvantaged_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__foster_care_status_id ON rds.fact_k12_student_enrollments (foster_care_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__immigrant_status_id ON rds.fact_k12_student_enrollments (immigrant_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__language_home_id ON rds.fact_k12_student_enrollments (language_home_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__language_native_id ON rds.fact_k12_student_enrollments (language_native_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__migrant_status_id ON rds.fact_k12_student_enrollments (migrant_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__military_status_id ON rds.fact_k12_student_enrollments (military_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments_n_or_d_status_id ON rds.fact_k12_student_enrollments (n_or_d_status_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__primary_disability_type_id ON rds.fact_k12_student_enrollments (primary_disability_type_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__secondary_disability_type_id ON rds.fact_k12_student_enrollments (secondary_disability_type_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__projected_graduation_date_id ON rds.fact_k12_student_enrollments (projected_graduation_date_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_economically_disadvantaged_id ON rds.fact_k12_student_enrollments (status_start_date_economically_disadvantaged_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_economically_disadvantaged_id ON rds.fact_k12_student_enrollments (status_end_date_economically_disadvantaged_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_english_learner_id ON rds.fact_k12_student_enrollments (status_start_date_english_learner_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_english_learner_id ON rds.fact_k12_student_enrollments (status_end_date_english_learner_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_homelessness_id ON rds.fact_k12_student_enrollments (status_start_date_homelessness_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_homelessness_id ON rds.fact_k12_student_enrollments (status_end_date_homelessness_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_idea_id ON rds.fact_k12_student_enrollments (status_start_date_idea_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_idea_id ON rds.fact_k12_student_enrollments (status_end_date_idea_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_migrant_id ON rds.fact_k12_student_enrollments (status_start_date_migrant_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_migrant_id ON rds.fact_k12_student_enrollments (status_end_date_migrant_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_military_connected_student_id ON rds.fact_k12_student_enrollments (status_start_date_military_connected_student_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_military_connected_student_id ON rds.fact_k12_student_enrollments (status_end_date_military_connected_student_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_perkins_english_learner_id ON rds.fact_k12_student_enrollments (status_start_date_perkins_english_learner_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_perkins_english_learner_id ON rds.fact_k12_student_enrollments (status_end_date_perkins_english_learner_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_end_date_title_iii_immigrant_id ON rds.fact_k12_student_enrollments (status_end_date_title_iii_immigrant_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__status_start_date_title_iii_immigrant_id ON rds.fact_k12_student_enrollments (status_start_date_title_iii_immigrant_id] asc);

CREATE INDEX ixfk__fact_k12_student_enrollments__title_iii_status_id ON rds.fact_k12_student_enrollments (title_iii_status_id] asc);

CREATE INDEX idx__fact_k12_student_enrollments__data_collection_id__with__includes ON rds.fact_k12_student_enrollments (data_collection_id] asc, school_year_id, sea_id, ieu_id, lea_accountability_id, k12_school_id, k12_student_id, k12_enrollment_status_id, entry_grade_level_id, exit_grade_level_id, enrollment_entry_date_id, enrollment_exit_date_id, projected_graduation_date_id, k12_demographic_id, idea_status_id, student_count);

COMMENT ON TABLE rds.fact_k12_student_enrollments IS 'Converted from SQL Server table [RDS].[FactK12StudentEnrollments]';