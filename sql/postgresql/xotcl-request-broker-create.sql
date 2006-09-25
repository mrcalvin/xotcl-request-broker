-- create new attribute for constraint support (array / multiple) in relation acs_sc_msg_type_elements

alter table acs_sc_msg_type_elements add column element_constraints varchar(100);

-- upgrade functions: new and overloaded constructor for msg_type_elements

drop function acs_sc_msg_type__new_element(varchar,varchar,varchar,boolean,integer);


create or replace function acs_sc_msg_type__new_element(varchar,varchar,varchar,boolean,integer)
returns integer as '
declare
    p_msg_type_name		alias for $1;
    p_element_name		alias for $2;
    p_element_msg_type_name	alias for $3;
    p_element_msg_type_isset_p	alias for $4;
    p_element_pos		alias for $5;
   v_msg_type_id		integer;
  
begin

     v_msg_type_id := acs_sc_msg_type__new_element(p_msg_type_name,p_element_name,p_element_msg_type_name,p_element_msg_type_isset_p,p_element_pos,null);
    return v_msg_type_id;
    
    

end;' language 'plpgsql';


create or replace function acs_sc_msg_type__new_element(varchar,varchar,varchar,boolean,integer,varchar)
returns integer as '
declare
    p_msg_type_name		alias for $1;
    p_element_name		alias for $2;
    p_element_msg_type_name	alias for $3;
    p_element_msg_type_isset_p	alias for $4;
    p_element_pos		alias for $5;
    p_element_constraints alias for $6;
    v_msg_type_id		integer;
    v_element_msg_type_id	integer;
begin

    v_msg_type_id := acs_sc_msg_type__get_id(p_msg_type_name);

    if v_msg_type_id is null then
        raise exception ''Unknown Message Type: %'', p_msg_type_name;
    end if;

    v_element_msg_type_id := acs_sc_msg_type__get_id(p_element_msg_type_name);

    if v_element_msg_type_id is null then
        raise exception ''Unknown Message Type: %'', p_element_msg_type_name;
    end if;

    insert into acs_sc_msg_type_elements (
    		msg_type_id,
		element_name,
		element_msg_type_id,
		element_msg_type_isset_p,
		element_pos,
		element_constraints
    ) values (
        v_msg_type_id,
		p_element_name,
		v_element_msg_type_id,
		p_element_msg_type_isset_p,
		p_element_pos,
		p_element_constraints
    );

    return v_msg_type_id;

end;' language 'plpgsql';

