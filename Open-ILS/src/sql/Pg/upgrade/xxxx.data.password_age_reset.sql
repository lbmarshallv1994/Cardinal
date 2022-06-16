BEGIN;

--SELECT evergreen.upgrade_deps_block_check('xxxx', :eg_version);

-- password age display setting

INSERT INTO config.org_unit_setting_type
    (name, grp, label, description, datatype)
    VALUES (
        'global.password_reset_age',
        'glob',
        oils_i18n_gettext(
            'global.password_reset_age',
            'Password Reset Age',
            'coust',
            'label'
        ),
        oils_i18n_gettext(
            'global.password_reset_age',
            'The number of days after a password has been changed before ' || 
			'users will be alerted that they should update it.',
            'coust',
            'description'
        ),
        'integer'
    );

INSERT INTO action_trigger.hook (key,core_type,description,passive) VALUES (
    'au.passwd_changed',
    'au',
    'A user\'s password was updated',
	false
);

INSERT INTO action_trigger.validator (module, description) VALUES (
    'PatronOldPassword', 'Confirm that the patron has not updated their password since this event was created.'
);

--ROLLBACK;
COMMIT;