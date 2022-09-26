CREATE TABLE action.hold_request_reset_reason
(
 id serial NOT NULL,
 manual  boolean,
 name text,
CONSTRAINT hold_request_reset_reason_pkey PRIMARY KEY (id),
CONSTRAINT hold_request_reset_reason_name_key UNIQUE (name)
) WITH (
  OIDS=FALSE
);

INSERT INTO action.hold_request_reset_reason (id, name, manual) VALUES
(1,'HOLD_TIMED_OUT',false),
(2,'HOLD_MANUAL_RESET',true),
(3,'HOLD_BETTER_HOLD',false),
(4,'HOLD_FROZEN',true),
(5,'HOLD_UNFROZEN',true),
(6,'HOLD_CANCELED',true),
(7,'HOLD_UNCANCELED',true),
(8,'HOLD_UPDATED',true),
(9,'HOLD_CHECKED_OUT',true),
(10,'HOLD_CHECKED_IN',true);

CREATE TABLE action.hold_request_reset_reason_entry
(
  id serial NOT NULL,
  hold int,
  reset_reason int,
  note text,
  reset_time timestamp with time zone,
  previous_copy bigint,
  requestor int,
  requestor_workstation int,
  CONSTRAINT hold_request_reset_reason_entry_pkey PRIMARY KEY (id),
  CONSTRAINT action_hold_request_reset_reason_entry_reason_fkey FOREIGN KEY (reset_reason)
      REFERENCES action.hold_request_reset_reason (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,  
CONSTRAINT action_hold_request_reset_reason_entry_previous_copy_fkey FOREIGN KEY (previous_copy)
      REFERENCES asset.copy (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT action_hold_request_reset_reason_entry_requestor_fkey FOREIGN KEY (requestor)
      REFERENCES actor.usr (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT action_hold_request_reset_reason_entry_requestor_workstation_fkey FOREIGN KEY (requestor_workstation)
      REFERENCES actor.workstation (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT action_hold_request_reset_reason_entry_hold_fkey FOREIGN KEY (hold)
      REFERENCES action.hold_request (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED
)

WITH (
  OIDS=FALSE
);

INSERT INTO config.global_flag (name, label, enabled)
    VALUES (
        'circ.holds.retarget_previous_targets_interval',
        oils_i18n_gettext(
            'circ.holds.retarget_previous_targets_interval',
            'Hold targeter will create proximity adjustments for previously targeted copies within this time interval (in days).',
            'cgf',
            'label'
        ),
        TRUE
    );
