BEGIN;

SELECT evergreen.upgrade_deps_block_check('1172', :eg_version);

INSERT INTO config.org_unit_setting_type ( name, label, description, datatype, grp )
    VALUES (
        'cat.format.icon.type',
        'Format Icon File Type',
        'File type of format icons displayed in the catalog',
        'string',
        'gui'
    );

COMMIT;
