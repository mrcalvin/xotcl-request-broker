-- factoring out the data model for request broker
-- from the acs-service-contract's one to provide
-- for orthogonality in this respect

-- TODO: to be removed when filed and realised as patch to acs-service-contract
-- schema

alter table acs_sc_msg_type_elements drop constraint "acs_sc_msg_type_elements_uq" cascade;

-- / / / / / / / / / / / / / / / / / / / / / / / / / / /

drop table xorb_msg_type_elements_ext;
drop function xorb_msg_type_element__new(
     varchar,
     varchar,
     varchar,
     boolean,
     integer,
     varchar);

-- / / / / / / / / / / / / / / / / / / / / / / / / / / /

