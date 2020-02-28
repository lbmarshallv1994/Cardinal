BEGIN;

INSERT INTO config.upgrade_log (version) VALUES ('1174'); 

CREATE TABLE actor.org_unit_shipping_hub_distance (
    id SERIAL PRIMARY KEY,
    orig_hub BIGINT NOT NULL REFERENCES actor.org_unit(id) ON DELETE CASCADE DEFERRABLE,
    dest_hub BIGINT NOT NULL REFERENCES actor.org_unit(id) ON DELETE CASCADE DEFERRABLE,
    distance INT NOT NULL
);

CREATE OR REPLACE FUNCTION actor.clear_org_unit_shipping_hub_distances()
  AS
  $func$
  BEGIN
    DELETE FROM actor.org_unit_shipping_hub_distance;
END;
$func$ LANGUAGE PLPGSQL;

COMMIT;