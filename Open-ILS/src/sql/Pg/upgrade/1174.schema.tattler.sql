BEGIN;

INSERT INTO config.upgrade_log (version) VALUES ('1174'); 

CREATE TABLE tattler.ignore_list (
    id SERIAL PRIMARY KEY,
    report_name TEXT,
    org_unit BIGINT NOT NULL REFERENCES actor.org_unit(id) ON DELETE CASCADE DEFERRABLE,
    target_copy BIGINT NOT NULL REFERENCES asset.copy(id) ON DELETE CASCADE DEFERRABLE
);
END;
$func$ LANGUAGE PLPGSQL;

COMMIT;