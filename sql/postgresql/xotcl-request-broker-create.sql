-- factoring out the data model for request broker
-- from the acs-service-contract's one to provide
-- for orthogonality in this respect

-- TODO: There is one 'minor' dependency left: SQL spec
-- PostgreSQL (since ever) do not allow referential
-- constraints on attributes in referenced relations
-- that are not explicitly subject to a unique constraint
-- (both for single- and multi-column constraints).
-- As the referenced relation 'acs_sc_msg_type_elements'
-- implies uniqueness on the coupling of attributes
-- 'msg_type_id' and 'element_name' but does not so
-- explicitly do so. Therefore, I, here, take care of
-- setting the unique key. However, I also submit
-- a bug report and a patch to have this solved in
-- a general manner.
-- http://openacs.org/bugtracker/openacs/bug?bug%5fnumber=3097

alter table acs_sc_msg_type_elements 
add constraint acs_sc_msg_type_elements_uq 
unique (msg_type_id,element_name);

-- / / / / / / / / / / / / / / / / / / / / / / / / / / /

create table xorb_msg_type_elements_ext (
       msg_type_id integer,
       element_name varchar(100),
       element_constraints varchar(100),
       primary key (msg_type_id, element_name),
       foreign key (msg_type_id, element_name) 
       	       references acs_sc_msg_type_elements (msg_type_id, element_name) 
       	       on delete cascade
);

-- register function record
select define_function_args ('xorb_msg_type_element__new','msg_type_name,element_name,element_msg_type_name,element_msg_type_isset_p,element_pos,element_constraints');
-- declare function
create or replace function xorb_msg_type_element__new(varchar,varchar,varchar,boolean,integer,varchar)
returns integer as '
declare
    p_msg_type_name		alias for $1;
    p_element_name		alias for $2;
    p_element_msg_type_name	alias for $3;
    p_element_msg_type_isset_p	alias for $4;
    p_element_pos		alias for $5;
    p_element_constraints	alias for $6;
    v_msg_type_id		integer;
    v_element_msg_type_id	integer;
begin

    v_msg_type_id := acs_sc_msg_type__new_element(p_msg_type_name,p_element_name,p_element_msg_type_name,p_element_msg_type_isset_p,p_element_pos);

    insert into xorb_msg_type_elements_ext (
        msg_type_id,
	element_name,
	element_constraints
    ) values (
        v_msg_type_id,
	p_element_name,
	p_element_constraints
    );

    return v_msg_type_id;

end;' language 'plpgsql';

-- / / / / / / / / / / / / / / / / / / / / / / / / / / /



