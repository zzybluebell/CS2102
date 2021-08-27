/* 
 * Q1: add a new employee
 * category: 1 manager; 2 administrator; 3 full time instructor; 4 part time instructor
 * course_area is nullable
 * course_areas: {"A", "B", "C"}
 * input: name, home address, contact number, email address, salary information 
 *        (i.e., monthly salary for a full-time employee or hourly rate for a part-time employee), 
 *        date that the employee joined the company, the employee category (manager, administrator, or instructor), 
 *        and a (possibly empty) set of course areas
 * output: 0 success
 */
create or replace function add_part_time_instructor_on_addition_of_part_time_emp() returns trigger as $$
begin
	insert into Part_time_instructors values (NEW.eid);
	return null;
END;
$$ language plpgsql;

-- drop trigger if exists add_part_time_instructor_on_addition_of_part_time_emp_trigger on Part_time_Emp;
create trigger add_part_time_instructor_on_addition_of_part_time_emp_trigger
after insert on Part_time_Emp
for each row execute function add_part_time_instructor_on_addition_of_part_time_emp();

create or replace function add_employee (_name varchar(100), _address text, _phone char(8), _email varchar(255), 
										 _salary decimal(10, 2), _join_date date, _category int, 
										 _course_areas varchar(100)[])
returns int as $$
declare
	current_eid int;
begin
	if (_category = 1 and _course_areas is not null and array_length(_course_areas, 1) > 0) 
			or (_category = 2 and (_course_areas is null or array_length(_course_areas, 1) = 0)) 
			or (_category = 3 and _course_areas is not null and array_length(_course_areas, 1) > 0)
			or (_category = 4 and _course_areas is not null and array_length(_course_areas, 1) > 0) then
		insert into Employees (phone, name, address, email, join_date) values (_phone, _name, _address, _email, _join_date) returning eid into current_eid;
		case _category
        	when 1 then
				insert into Full_time_Emp values (current_eid, _salary);
				insert into Managers values (current_eid);
				for i in array_lower(_course_areas, 1) .. array_upper(_course_areas, 1)
				loop
      				insert into Course_areas_Manages values (_course_areas[i], current_eid);
   				end loop;
        	when 2 then
				insert into Full_time_Emp values (current_eid, _salary);
				insert into Administrators values (current_eid);
			when 3 then
				insert into Full_time_Emp values (current_eid, _salary);
				insert into Instructors values (current_eid);
				insert into Full_time_instructors values (current_eid);
				for i in array_lower(_course_areas, 1) .. array_upper(_course_areas, 1)
				loop
      				insert into Specializes values (current_eid, _course_areas[i]);
   				end loop;
        	else
				insert into Instructors values (current_eid);
				insert into Part_time_Emp values (current_eid, _salary);
				--use trigger to insert into Part_time_instructors
				for i in array_lower(_course_areas, 1) .. array_upper(_course_areas, 1)
				loop
      				insert into Specializes values (current_eid, _course_areas[i]);
   				end loop;
    	end case;
	else
		raise exception 'category or course_areas error';
	end if;
	return 0;
end;
$$ language plpgsql;

/* 
 * Q2: update an employee’s departed date a non-null value
 * input: an employee identifier and a departure date
 * output: 0 success
 */
create or replace function remove_employee (_eid int, _depart_date date)
returns int as $$
declare
	current_eid int;
	num_of_records int;
begin
	num_of_records := 0;
	-- check if manager
	if current_eid is null then
		select eid from Managers where eid = _eid into current_eid;
		if current_eid is not null then
			-- update reject: the employee is a manager who is managing some area
			select count(*) from Course_areas_Manages where eid = _eid into num_of_records;
			if num_of_records <> 0 then
				raise exception 'managers remove rejected';
			else
				update Employees set depart_date = _depart_date where eid = _eid;
				return 0;
			end if;
		end if;
	end if;
	-- check if administrator
	if current_eid is null then
		select eid from Administrators where eid = _eid into current_eid;
		if current_eid is not null then
			-- update reject: the employee is an administrator who is handling some course offering where its registration deadline is after the employee’s departure date
			select count(*) from Offerings_Has_Handles where eid = _eid and registration_deadline > _depart_date into num_of_records;
			if num_of_records <> 0 then
				raise exception 'administrators remove rejected';
			else
				update Employees set depart_date = _depart_date where eid = _eid;
				return 0;
			end if;
		end if;
	end if;
	-- check if instructor
	if current_eid is null then
		select eid from Instructors where eid = _eid into current_eid;
		if current_eid is not null then
			-- the employee is an instructor who is teaching some course session that starts after the employee’s departure date
			select count(*) from Sessions_Conducts_Consists where eid = _eid and is_valid = 0 and date > _depart_date into num_of_records;
			if num_of_records <> 0 then
				raise exception 'instructors remove rejected';
			else
				update Employees set depart_date = _depart_date where eid = _eid;
				return 0;
			end if;
		end if;
	end if;
	raise exception 'remove nothing';
end;
$$ language plpgsql;

/* 
 * Q3: add a new customer
 * input: name, home address, contact number, email address, and credit card details (credit card number, expiry date, CVV code).
 * output: 0 success
 */
create or replace function add_customer (_name varchar(100), _address text, _phone char(8), _email varchar(255), 
										 _credit_card_number varchar(20), _expiry_date date, _CVV varchar(4))
returns int AS $$
declare
	current_cust_id int;
	year int;
	month int;
begin
	year := EXTRACT(YEAR FROM _expiry_date);
	month := EXTRACT(MONTH FROM _expiry_date);
	insert into Customers (address, phone, name, email) values (_address, _phone, _name, _email) returning cust_id into current_cust_id;
	insert into Credit_cards (number, expiry_year, expiry_month, CVV, cust_id) values (_credit_card_number, year, month, _CVV, current_cust_id);
	return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q4: a customer requests to change his/her credit card details
 * input: the customer identifier and his/her new credit card details (credit card number, expiry date, CVV code)
 * output: 0 success 
 */
create or replace function update_credit_card (_cust_id int, _credit_card_number varchar(20), _expiry_date date, _CVV varchar(4))
returns int AS $$
declare
	year int;
	month int;
	num_of_cust_ids int;
	num_of_credit_cards int;
	current_cust_id int;
begin
	num_of_cust_ids := 0;
	num_of_credit_cards := 0;
	select count(*) from Customers where cust_id = _cust_id into num_of_cust_ids;
	if num_of_cust_ids = 0 then
		raise exception 'customer not exists';
	end if;
	select count(*) from Credit_cards where number = _credit_card_number into num_of_credit_cards;
	select cust_id from Credit_cards where number = _credit_card_number into current_cust_id;
	year := EXTRACT(YEAR FROM _expiry_date);
	month := EXTRACT(MONTH FROM _expiry_date);
	if num_of_credit_cards = 0 then
		insert into Credit_cards (number, expiry_year, expiry_month, CVV, cust_id) values (_credit_card_number, year, month, _CVV, _cust_id);
	else
		if current_cust_id <> _cust_id then
			raise exception 'someone is holding the card';
		else 
			update Credit_cards Set expiry_year = year, expiry_month = month, CVV = _CVV where number = _credit_card_number;
		end if;
	end if;
	return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q5: add a new course
 * input: course title, course description, course area, and duration
 * output: 0 success
 */
create or replace function add_course (_course_title varchar(100), _course_description text, _course_area varchar(100), _course_duration int)
returns int AS $$
begin
	insert into Courses_In (duration, description, title, name) values (_course_duration, _course_description, _course_title, _course_area);
	return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q6: find all the instructors who could be assigned to teach a course session
 * input: course identifier, session date, and session start hour
 * output: a table of records consisting of employee identifier and name
 */
create or replace function get_all_instructors (_course_identifier int)
returns Table(_eid int, _name varchar(100)) AS $$
DECLARE
begin
	return query select eid, name from Employees where eid in (
		select eid from Specializes where name in (
			select name from Courses_In where course_id = _course_identifier
		)
	);
end;
$$ LANGUAGE plpgsql;

create or replace function find_instructors (_course_identifier int, _session_date date, _session_start_hour time)
returns Table(employeeIdentifier int, name varchar(255)) AS $$
DECLARE
	r RECORD;
	totalHours int;
	totalSessions int;
	isPartTime int;
begin
	if _course_identifier is null or _session_date is null or _session_start_hour is null then
		raise exception 'error input';
	end if;
	if extract(minute from _session_start_hour) <> 0 or extract(second from _session_start_hour) <> 0
			or extract(hour from _session_start_hour) not in (9, 10, 11, 14, 15, 16, 17) then
		raise exception 'session start hour is invalid';
	end if;
	if extract(dow from _session_date) not in (1, 2, 3, 4, 5) then
		raise exception ' session date is invalid';
	end if;
	for r in select * from get_all_instructors(_course_identifier) order by _eid asc
	LOOP
		select count(*) from Part_time_instructors where eid = r._eid into isPartTime;
		if (isPartTime != 0) then 
				select case when sum(extract(hour from (end_time - start_time))) is not null then sum(extract(hour from (end_time - start_time))) else 0 end 
				from Sessions_Conducts_Consists where eid = r._eid and is_valid = 0 into totalHours;
				if (totalHours < 30) then
					-- assume one session one hour
					select count(*) from Sessions_Conducts_Consists as SCC where SCC.eid = r._eid and _session_date = SCC.date and (start_time = _session_start_hour
					or (end_time = _session_start_hour) or (_session_start_hour + interval '1 hour' = start_time)) and SCC.is_valid = 0 into totalSessions;
					if (totalSessions = 0) then
						employeeIdentifier := r._eid;
						name := r._name;
						RETURN NEXT;
					end IF;
				end IF;
		end IF;
		if (isPartTime = 0) then 
			-- assume one session one hour
			select count(*) from Sessions_Conducts_Consists as SCC where SCC.eid = r._eid and _session_date = SCC.date and (start_time = _session_start_hour
			or (end_time = _session_start_hour) or (_session_start_hour + interval '1 hour' = start_time)) and SCC.is_valid = 0 into totalSessions;
			if (totalSessions = 0) then
				employeeIdentifier := r._eid;
				name := r._name;
				RETURN NEXT;
			end IF;
		end IF;
	end Loop;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q7: 
 * input: retrieve the availability information of instructors who could be assigned to teach a specified course
 * output: employee identifier, name, total number of teaching hours that the instructor has been assigned for this month, 
 * day (which is within the input date range [start date, end date]), and an array of the available hours for the instructor on the specified day.
 */
create or replace function get_available_instructors (_course_identifier int, _start_date date, _end_date date)
returns Table(employeeIdentifier int, name varchar(100), totalTeachingHours int, day date, availableHoursR time[]) AS $$
begin
	if _start_date > _end_date then
		raise exception 'start date must be smaller than end date';
	end if;
	return query select 
	r.eid, 
	r.name, 
	(SELECT case when sum(extract (hour from (SC.end_time - SC.start_time))) is not null then sum(extract (hour from (SC.end_time - SC.start_time))) else 0 end 
	 FROM Sessions_Conducts_Consists SC 
	 where r.eid = SC.eid and SC.is_valid = 0 and (EXTRACT (MONTH FROM SC.date)) = EXTRACT(MONTH FROM _start_date))::INTEGER as totalHours, 
	r.adate, 
	(select array_agg(hour) as arr
		from (values (time '09:00'),(time '10:00'),(time '11:00'),(time '14:00'), (time '15:00'),(time '16:00'),(time '17:00')) AllHours(hour)
			where not exists (select 1 from Sessions_Conducts_Consists SCC 
			where r.eid = SCC.eid and SCC.is_valid = 0 and SCC.date = r.adate and SCC.start_time = AllHours.hour) and 
	 		not exists ( 
				select 1 from Sessions_Conducts_Consists SCC2 
				where r.eid = SCC2.eid and SCC2.date = r.adate 
				and (SCC2.start_time = AllHours.hour - interval '1 hour' or SCC2.start_time = AllHours.hour + interval '1 hour')
			)	 
	) from 
	(SELECT 
	 eid, 
	 (select E.name from Employees E where E.eid = SP.eid), adate FROM Specializes SP, 
	 (select i::date from generate_series(_start_date, _end_date, '1 day'::interval) i) as DatesSE(adate)
	 where (SP.name = (select CI.name from Courses_In CI where CI.course_id = _course_identifier)) order by eid) as r
	where (((r.eid in (select eid from Part_time_instructors)) 
		and (SELECT count(*) FROM Sessions_Conducts_Consists SC where r.eid = SC.eid and (EXTRACT (MONTH FROM SC.date)) = EXTRACT(MONTH FROM _start_date)) <30) 
		or (r.eid in (select eid from Full_time_instructors))) 
		and extract(dow from r.adate) in (1, 2, 3, 4, 5) 
		and ((select array_agg(hour) as arr from (values (time '09:00'),(time '10:00'),(time '11:00'),(time '14:00'), (time '15:00'),(time '16:00'),(time '17:00')) AllHours(hour)
				where not exists (select 1 from Sessions_Conducts_Consists SCC 
				where r.eid = SCC.eid and SCC.is_valid = 0 and 
				SCC.date = r.adate and SCC.start_time = AllHours.hour) and 
				not exists ( 
					select 1 from Sessions_Conducts_Consists SCC2 where r.eid = SCC2.eid and SCC2.date = r.adate 
							and (SCC2.start_time = AllHours.hour - interval '1 hour' or SCC2.start_time = AllHours.hour + interval '1 hour')
				)) is not null
		)
	order by r.eid, r.adate;
	return;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q8: find all the rooms that could be used for a course session
 * input: session date, session start hour, and session duration
 * output: a table of room identifiers 
 */
create or replace function find_rooms (_session_date date, _session_start_hour time, _session_duration int)
returns Table(rid int) AS $$
begin
	if _session_duration is null or _session_date is null or _session_start_hour is null then
		raise exception 'error input';
	end if;
	if extract(minute from _session_start_hour) <> 0 or extract(second from _session_start_hour) <> 0
			or extract(hour from _session_start_hour) not in (9, 10, 11, 14, 15, 16, 17) then
		raise exception 'session start hour is invalid';
	end if;
	if extract(dow from _session_date) not in (1, 2, 3, 4, 5) then
		raise exception ' session date is invalid';
	end if;
	return query select R.rid
	from Rooms as R
	where R.rid not in (
		select SCC.rid
		from Sessions_Conducts_Consists as SCC
		where ((_session_start_hour < SCC.start_time and interval '1 hour' * _session_duration + _session_start_hour > SCC.end_time) 
			or (interval '1 hour' * _session_duration + _session_start_hour > SCC.start_time
			and interval '1 hour' * _session_duration + _session_start_hour < SCC.end_time) 
			or (_session_start_hour = SCC.start_time or interval '1 hour' * _session_duration + _session_start_hour = SCC.end_time))
			and SCC.date = _session_date
			and SCC.is_valid = 0
	);
end;
$$ LANGUAGE plpgsql;

/* 
 * Q9: retrieve the availability information of rooms for a specific duration
 * input: a start date and an end date
 * output: room identifier, room capacity, day (which is within the input date range [start date, end date]), 
 * and an array of the hours that the room is available on the specified day.
 */
create or replace function get_available_rooms (_start_date date, _end_date date) 
returns Table(roomIdentifier int, roomCapacity int, day date, availableHours time[]) AS $$
DECLARE
begin
	if _start_date > _end_date then
		raise exception 'start date must be smaller than end date';
	end if;
	return query select distinct 
	r.rid, 
	r.seating_capacity, 
	r.aDate, 
	(select array_agg(hour) as arr from (values (time '09:00'),(time '10:00'),(time '11:00'),(time '14:00'), (time '15:00'),(time '16:00'),(time '17:00')) AllHours(hour) 
		where not exists (
			select 1 from Sessions_Conducts_Consists SCC 
			where SCC.is_valid = 0 and SCC.rid = r.rid and SCC.date = r.adate 
			and (SCC.start_time = AllHours.hour or (SCC.start_time < AllHours.hour and AllHours.hour < SCC.end_time)))
	) 
	from (
	 select * from 
		(Rooms natural left join Sessions_Conducts_Consists) as RSCC, 
		(select i::date from generate_series(_start_date,_end_date, '1 day'::interval) i ) as DatesSE(adate) 
		order by RSCC.rid) as r where extract(dow from r.adate) in (1, 2, 3, 4, 5) 
		and (select array_agg(hour) as arr from (values (time '09:00'),(time '10:00'),(time '11:00'),(time '14:00'), (time '15:00'),(time '16:00'),(time '17:00')) AllHours(hour)
		where not exists (
			select 1 from Sessions_Conducts_Consists SCC 
			where SCC.is_valid = 0 and SCC.date = r.adate 
			and (SCC.start_time = AllHours.hour or (SCC.start_time < AllHours.hour and AllHours.hour < SCC.end_time))
		)) is not null
	order by r.rid, r.adate;
	return;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q10: a new offering of an existing course
 * input: course offering identifier, course identifier, course fees, launch date, registration deadline, administrator’s identifier, 
 * and information for each session (session date, session start hour, and room identifier).
 * _course_offering_identifier = _course_identifier + _launch_date, it is useless
 * output: 0 success 
 */
create or replace function add_course_offering (_course_offering_identifier int, _course_identifier int, _course_fees decimal(10, 2), _launch_date date,
_registration_deadline date, _target_number_of_registrations int, _administrator_identifier int, _seesion_information varchar(100)[][]) 
returns int AS $$
DECLARE
	r record;
	listOfInstructor record;
	instructorID int;
	roomID int;
	totalSeatingCapacity int;
 begin
	totalSeatingCapacity := 0;
	for i in array_lower(_seesion_information, 2)..array_upper(_seesion_information, 2) 
	loop
		-- the registration deadline for a course offering must be at least 10 days before its start date.
 		if _registration_deadline + interval '1 day' * 10 > (to_date(_seesion_information[i][1], 'YYYY-MM-DD')) then
			raise exception 'the registration deadline must be at least 10 days before its session''s start date';
		end If;
	end loop;
	-- insert a default record first
	insert into Offerings_Has_Handles values 
			(_launch_date, _course_identifier, _registration_deadline + interval '1 day' * 10, _registration_deadline + interval '1 day' * 10, _registration_deadline , 0, 0, _course_fees, _administrator_identifier);
	for i in array_lower(_seesion_information, 1)..array_upper(_seesion_information, 1) 
	loop
		-- find all the instructors who could be assigned to teach a course session
		select employeeIdentifier from find_instructors(_course_identifier, to_date(_seesion_information[i][1], 'YYYY-MM-DD'), TO_TIMESTAMP(_seesion_information[i][2], 'HH24:MI:SS')::TIME) limit 1 into instructorID;
		if instructorID is not null then 
			perform * from add_session(_launch_date, _course_identifier, i, to_date(_seesion_information[i][1], 'YYYY-MM-DD'), TO_TIMESTAMP(_seesion_information[i][2], 'HH24:MI:SS')::TIME, instructorID, _seesion_information[i][3]::integer);	
		else
			raise exception 'all instructors are occupied';
		end IF;
	end loop;
	select seating_capacity from Offerings_Has_Handles where launch_date = _launch_date and course_id = _course_identifier into totalSeatingCapacity;
	if (totalSeatingCapacity < _target_number_of_registrations) then 
		raise exception 'seating capacity less than number of registration';
	else 
		update Offerings_Has_Handles set target_number_registrations = _target_number_of_registrations where launch_date = _launch_date and course_id = _course_identifier;
	end if;
	return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q11: add a new course package for sale
 * input: package name, number of free course sessions, start and end date indicating the duration that the promotional package is available for sale, and the price of the package
 * output: 0 success
 */
create or replace function add_course_package (_package_name varchar(100), _num_free_registrations int, _sale_start_date date, _sale_end_date date, _price decimal(10, 2))
returns int AS $$
declare
	package_id int;
begin
	if (_sale_start_date >= '2000-01-01' and _sale_start_date <= '2099-12-31' 
			and _sale_end_date >= CURRENT_DATE and _sale_end_date <= '2099-12-31' 
				and _sale_start_date <= _sale_end_date) then
		insert into Course_packages (name, num_free_registrations, sale_start_date, sale_end_date, price) values (_package_name, _num_free_registrations, _sale_start_date, _sale_end_date, _price);
	else
		raise exception 'start date and/or end date is invalid';
	end if;
	return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q12: retrieve the course packages that are available for sale
 * output: a table of records with the following information for each available course package: 
 * package name, number of free course sessions, end date for promotional package, and the price of the package
 */
create or replace function get_available_course_packages ()
returns Table(package_name varchar(100), num_free_registrations int, sale_end_date date, price decimal(10, 2)) AS $$
	select name, num_free_registrations, sale_end_date, price
	from Course_packages P
	where P.sale_end_date >= CURRENT_DATE and P.sale_start_date <= CURRENT_DATE;
$$ LANGUAGE sql;

/* 
 * Q13: a customer requests to purchase a course package
 * input: customer and course package identifiers
 * return: 0 success
 */
create or replace function buy_course_package (_cust_id int, _package_id int)
returns int AS $$
declare
	current_num_free_registrations int;
	current_credit_card varchar(20);
begin
	select num_free_registrations from Course_packages 
		where package_id= _package_id and sale_end_date >= CURRENT_DATE and sale_start_date <= CURRENT_DATE into current_num_free_registrations;
	-- select default card
	select number from Credit_cards CC where (CC.cust_id = _cust_id) and (
		CC.expiry_year > extract (year from CURRENT_DATE) 
		or (CC.expiry_year = extract (year from CURRENT_DATE) and CC.expiry_month >= extract (month from CURRENT_DATE))
	) limit 1 into current_credit_card;
	if (current_num_free_registrations is not null) then
		if (current_credit_card is not null) then
			insert into Buys (number, package_id, num_remaining_redemptions) values (current_credit_card, _package_id, current_num_free_registrations);
		else
			raise exception 'customer does not have valid credit card for payment';
		end if;
	else
		raise exception 'course package does not exist';
	end if;
return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q14: view his/her active/partially active course package
 * input: a customer identifier
 * return: json
 * package name, purchase date, price of package, number of free sessions included in the package, 
 * number of sessions that have not been redeemed, and information for each redeemed session (course name, session date, session start hour). 
 * The redeemed session information is sorted in ascending order of session date and start hour.
*/
create or replace function get_my_course_package (in _cust_id int)
returns json AS $$
	select json_agg(t) 
		FROM (
			(select 
			(select name from Course_Packages C where B.package_id = C.package_id), 
			B.date, 
			(select price from Course_Packages C where B.package_id = C.package_id), 
			(select num_free_registrations from Course_Packages C where B.package_id = C.package_id), 
			B.num_remaining_redemptions, 
			null as name,
			null as date,
			null as start_date
			from Buys B
			where B.number = (select number from Credit_cards where cust_id= _cust_id)
			and (B.num_remaining_redemptions 
				 = (select num_free_registrations from Course_Packages C where B.package_id = C.package_id))
 			) 
			union
			(select 
			(select name from Course_Packages C where B.package_id = C.package_id), 
			B.date, 
			(select price from Course_Packages C where B.package_id = C.package_id), 
			(select num_free_registrations from Course_Packages C where B.package_id = C.package_id), 
			B.num_remaining_redemptions, 
			(select name from Courses_In CI where S.course_id = CI.course_id),
			S.date,
			S.start_time
			from Buys B, Redeem R, Sessions_Conducts_Consists S
			where (B.package_id = R.package_id) and (R.buy_date = B.date) and (B.number = R.number)
			and (R.sid = S.sid) and (R.launch_date = S.launch_date) and (R.course_id = S.course_id)
			and R.number = (select number from Credit_cards where cust_id= _cust_id)
			and (B.num_remaining_redemptions > 0 
	 			or ((B.num_remaining_redemptions = 0) 
		 			and (exists (select 1 from Redeem R1 
					  			where (B.package_id = R1.package_id) and (R1.buy_date = B.date) and (B.number = R1.number) 
					  			and (S.date - current_date >= 7)) )))
			and S.is_valid = 0
			order by row(S.date, S.start_time)
 			)
	) as t;
$$ LANGUAGE sql;

/* 
 * Q15: retrieve all the available course offerings that could be registered
 * input: null
 * output: a table of records with the following information for each course offering: 
 * course title, course area, start date, end date, registration deadline, course fees, and the number of remaining seats. 
 * The output is sorted in ascending order of registration deadline and course title.
 */
create or replace function get_available_course_offerings (out course_title varchar(100), out course_area varchar(100), 
														   out start_date date, out end_date date, out registration_deadline date,
														  out course_fee decimal(10,2), out num_remaining_seats bigint)
returns setof record AS $$
	select 
		(select title from Courses_In CI where O.course_id = CI.course_id) as CItitle,
		(select name from Courses_In CI where O.course_id = CI.course_id),
		O.start_date, O.end_date, O.registration_deadline, O.fees, 
		O.seating_capacity - (select count(*) from Register RG where RG.course_id = O.course_id and RG.launch_date = O.launch_date) 
				- (select count(*) from Redeem RD where RD.course_id = O.course_id and RD.launch_date = O.launch_date)
	from Offerings_Has_Handles O
	-- before the registration deadline
	where current_date <= O.registration_deadline 
	-- a course offering is said to be available if the number of registrations received is no more than its seating capacity;
	and (O.seating_capacity 
			- (select count(*) from Register RG where RG.course_id = O.course_id and RG.launch_date = O.launch_date) 
		 	- (select count(*) from Redeem RD where RD.course_id = O.course_id and RD.launch_date = O.launch_date) > 0)
	order by O.registration_deadline, CItitle;
$$ LANGUAGE sql;

/* 
 * Q16: retrieve all the available sessions for a course offering that could be registered
 * input: course offering identifier
 * output: returns a table of records with the following information for each available session: session date, session start hour, 
 * instructor name, and number of remaining seats for that session. The output is sorted in ascending order of session date and start hour.
 */
create or replace function get_available_course_sessions (in _course_id int, in _launch_date date,
	out session_date date, out session_start_hour time, 
	out instructor_name varchar(100), out num_remaining_seats bigint)
returns setof record AS $$
	select 
	S.date, S.start_time, (select name from Employees where eid = S.eid),
	(
		(select R.seating_capacity from Rooms R where R.rid = S.rid)
		- (select count(*) from Redeem R where (R.sid = S.sid) and (R.course_id = _course_id) and (R.launch_date = _launch_date))
 		- (select count(*) from Register RG where (RG.sid = S.sid) and (RG.course_id = _course_id) and (RG.launch_date = _launch_date))
	)
	from Sessions_Conducts_Consists S
	where (S.course_id = _course_id) and (S.launch_date = _launch_date) and
	((select registration_deadline from Offerings_Has_Handles O1 where (S.course_id = O1.course_id) and (O1.launch_date = _launch_date)) >= current_date)
	and ((select R.seating_capacity from Rooms R where R.rid = S.rid)
		- (select count(*) from Redeem R where (R.sid = S.sid) and (R.course_id = _course_id) and (R.launch_date = _launch_date))
 		- (select count(*) from Register RG where (RG.sid = S.sid) and (RG.course_id = _course_id) and (RG.launch_date = _launch_date))
	) > 0
	and S.is_valid = 0
order by S.date, S.start_time;
$$ LANGUAGE sql;

/* 
 * Q17: a customer requests to register for a session in a course offering
 * input: customer identifier, course offering identifier, session number, and payment method (credit card or redemption from active package).
 * output: 0 success
 */
create or replace function decrement_num_remaining_redemptions() returns trigger as $$
begin
	update Buys B set num_remaining_redemptions = B.num_remaining_redemptions - 1
	where (B.date = NEW.buy_date and NEW.number = B.number and NEW.package_id = B.package_id);
	return null;
END;
$$ language plpgsql;

-- drop trigger if exists decrement_num_remaining_redemptions_trigger on Redeem;
create trigger decrement_num_remaining_redemptions_trigger
after insert on Redeem
for each row execute function decrement_num_remaining_redemptions();

create or replace function register_session (in _cust_id int, in _course_id int, in _launch_date date,
											  in _sid int, in _payment_method int)
returns int AS $$
declare
	current_package_id int;
	current_buy_date date;
	current_number_redeem varchar(20);
	current_num_remaining_redemptions int;
	current_credit_card varchar(20);
	registration_successful int;
	alr_exist int;
begin
	select 1 into registration_successful
	from Sessions_Conducts_Consists S
	where S.course_id = _course_id and S.launch_date = _launch_date and S.sid = _sid and S.is_valid = 0
	and ((select registration_deadline from Offerings_Has_Handles O1 where (S.course_id = O1.course_id) and (O1.launch_date = _launch_date)) >= current_date)
	and ((select R.seating_capacity from Rooms R where R.rid = S.rid)
			- (select count(*) from Redeem R where (R.sid = S.sid) and (R.course_id = _course_id) and (R.launch_date = _launch_date))
			- (select count(*) from Register RG where (RG.sid = S.sid) and (RG.course_id = _course_id) and (RG.launch_date = _launch_date))
			) > 0;
	-- number, package_id, sid, launch_date, course_id
	select 
	((select count(*) from Redeem R 
	 where (R.course_id = _course_id) and (R.launch_date = _launch_date)
	and (select number from Credit_cards CC where CC.cust_id = _cust_id) = R.number)
	+
	(select count(*) from Register RG --number, sid, launch_date, course_id
	 where (RG.course_id = _course_id) and (RG.launch_date = _launch_date)
	and (select number from Credit_cards CC where CC.cust_id = _cust_id) = RG.number))
	into alr_exist;
	if (registration_successful = 1) then
		if (alr_exist = 0) then
		-- if pay using redeemption
		-- need to update redeem table 
			if (_payment_method = 1) then 
				-- first check if there is any available package with num of free registration > 0
				select B.package_id, B.date, B.number, B.num_remaining_redemptions
				from Buys B
				where B.number = (select number from Credit_cards where cust_id = _cust_id)
				and B.num_remaining_redemptions > 0
				limit 1
				into current_package_id, current_buy_date, current_number_redeem, current_num_remaining_redemptions;
				-- if an active package exist
				if (current_num_remaining_redemptions is not null) then
					insert into Redeem (buy_date, number, package_id, sid, launch_date, course_id) values (current_buy_date, current_number_redeem, current_package_id, _sid, _launch_date, _course_id);
					-- update num_remaining_redemptions to curr - 1
					--update Buys B set num_remaining_redemptions = current_num_remaining_redemptions - 1
					--where (B.date = current_buy_date and current_number_redeem = B.number and current_package_id = B.package_id);
					registration_successful := 0;
				else 
					raise exception 'no valid package with sufficient remaining redemptions';
				end if;
			elseif (_payment_method = 0) then 
			-- payment by bank card
			-- first check if _cust_id has a valid card
				select number into current_credit_card from Credit_cards CC 
				where (CC.cust_id = _cust_id) 
				and ((CC.expiry_year > extract(year from current_date))
				or ((expiry_year = extract(year from current_date)) and (expiry_month >= extract(month from current_date))));
				if (current_credit_card is not null) then
					insert into Register (number, sid, launch_date, course_id) values (current_credit_card, _sid, _launch_date, _course_id);
					-- no need to update num_remaining_redemptions
					registration_successful := 0;
				else 
					raise exception 'no valid credit card for payment';
				end if;
			else 
				raise exception 'payment method not supported. Should be 0 for credit card payment, or 1 for package payment';
			end if;
		else 
			raise exception 'this customer already registered for a session for this course';
		end if;
	else
		raise exception 'session does not exist or run out of seats';
	end if;
	return registration_successful;
end;
$$ LANGUAGE plpgsql;

/* 
 * Q18: a customer requests to view his/her active course registrations
 * input: a customer identifier
 * return: table of records
 * for each active registration session: course name, course fees, session date, session start hour, session duration, and instructor name
 * The output is sorted in ascending order of session date and session start hour.
 */
create or replace function get_my_registrations (in _cust_id int)
returns TABLE(course_name varchar(100), fee decimal(10, 2), session_date date, session_start_hour time, session_duration double precision, instr_name varchar(100)) AS $$
	select name, fees, start_date, start_hour, duration, instr_name from (
		--register
		select (select CI.name from Courses_In CI where RG.course_id = CI.course_id),
		(select O.fees from Offerings_Has_Handles O where (RG.launch_date = O.launch_date) and (RG.course_id = O.course_id)),
		(select S.date from Sessions_Conducts_Consists S where (RG.sid = S.sid) and (RG.launch_date = S.launch_date) and (RG.course_id = S.course_id) and S.is_valid = 0) as start_date,
		(select S.start_time from Sessions_Conducts_Consists S where (RG.sid = S.sid) and (RG.launch_date = S.launch_date) and (RG.course_id = S.course_id) and S.is_valid = 0) as start_hour,
		(select (extract(hour from (S.end_time - S.start_time))) from Sessions_Conducts_Consists S where (RG.sid = S.sid) and (RG.launch_date = S.launch_date) and (RG.course_id = S.course_id) and S.is_valid = 0) as duration,
		(select name from Employees where eid = (select S.eid from Sessions_Conducts_Consists S where (RG.sid = S.sid) and (RG.launch_date = S.launch_date) and (RG.course_id = S.course_id) and S.is_valid = 0)) as instr_name
		from Register RG
		where (select O.registration_deadline from Offerings_Has_Handles O where (RG.launch_date = O.launch_date) and (RG.course_id = O.course_id)) >= current_date
		and (RG.number in (select number from Credit_cards where cust_id = _cust_id))
		union
		--redeem
		select (select CI.name from Courses_In CI where RR.course_id = CI.course_id),
		(select O.fees from Offerings_Has_Handles O where (RR.launch_date = O.launch_date) and (RR.course_id = O.course_id)),
		(select S.date from Sessions_Conducts_Consists S where (RR.sid = S.sid) and (RR.launch_date = S.launch_date) and (RR.course_id = S.course_id) and S.is_valid = 0) as start_date,
		(select S.start_time from Sessions_Conducts_Consists S where (RR.sid = S.sid) and (RR.launch_date = S.launch_date) and (RR.course_id = S.course_id) and S.is_valid = 0) as start_hour,
		(select (extract (hour from (S.end_time - S.start_time))) from Sessions_Conducts_Consists S where (RR.sid = S.sid) and (RR.launch_date = S.launch_date) and (RR.course_id = S.course_id) and S.is_valid = 0) as duration,
		(select name from Employees where eid = (select S.eid from Sessions_Conducts_Consists S where (RR.sid = S.sid) and (RR.launch_date = S.launch_date) and (RR.course_id = S.course_id) and S.is_valid = 0)) as instr_name
		from Redeem RR
		where (select O.registration_deadline from Offerings_Has_Handles O where (RR.launch_date = O.launch_date) and (RR.course_id = O.course_id)) >= current_date
		and (RR.number in (select number from Credit_cards where cust_id = _cust_id))
	) as MR order by start_date, start_hour;
$$ LANGUAGE sql;

/* 
 * Q19: a customer requests to change a registered course (same course offering) session to another session
 * launch_date + course_id is course offering identifier 
 * input: customer identifier, course offering identifier, and new session number
 * output: 0 success
 */
create or replace function update_course_session (_cust_id int, _launch_date date, _course_id int, _sid int)
returns int as $$
declare
	current_registration_deadline date;
	new_session_seating_capacity int;
	num_of_new_session_registrations int;
	num_of_new_session_redemptions int;
	current_session_sid int;
	register_or_redeem int; -- 0 register; 1 redeem
begin
	num_of_new_session_registrations := 0;
	num_of_new_session_redemptions := 0;
	register_or_redeem := 0;
	-- for each course offered by the company, a customer can register for at most one of its sessions before its registration deadline
	-- find registration deadline
	select registration_deadline from Offerings_Has_Handles 
	where launch_date = _launch_date and course_id = _course_id
	into current_registration_deadline;
	if current_registration_deadline is null then
		raise exception 'course offering identifier is invlid';
	end if;
	if current_registration_deadline >= current_date then
		-- the seating capacity of a course session is equal to the seating capacity of the room where the session is conducted
		-- new session seating capacity
		select R.seating_capacity from Sessions_Conducts_Consists as SCC 
		inner join Rooms as R on SCC. rid = R.rid
		where SCC.launch_date = _launch_date and SCC.course_id = _course_id and SCC.sid = _sid and SCC.is_valid = 0 into new_session_seating_capacity;
		-- register = register + redeem
		-- search register table
		select count(*) from Sessions_Conducts_Consists as SCC
		inner join Register as R on SCC.launch_date = R.launch_date and SCC.course_id = R.course_id and SCC.sid = R.sid
		where SCC.launch_date = _launch_date and SCC.course_id = _course_id and SCC.sid = _sid and SCC.is_valid = 0 into num_of_new_session_registrations;
		-- search redeem table
		select count(*) from Sessions_Conducts_Consists as SCC
		inner join Redeem as R on SCC.launch_date = R.launch_date and SCC.course_id = R.course_id and SCC.sid = R.sid
		where SCC.launch_date = _launch_date and SCC.course_id = _course_id and SCC.sid = _sid and SCC.is_valid = 0 into num_of_new_session_redemptions;
		-- new session seating capacity is enough
		if new_session_seating_capacity > num_of_new_session_registrations + num_of_new_session_redemptions then
			-- precondition: a customer only registered for at most one of its sessions for each course offering, so only one record will be shown below
			-- register = register + redeem
			-- search register table
			select SCC.sid from Customers as Cust 
			inner join Credit_cards as Cred on Cust.cust_id = Cred.cust_id
			inner join Register as R on Cred.number = R.number
			inner join Sessions_Conducts_Consists as SCC on SCC.launch_date = R.launch_date and SCC.course_id = R.course_id and SCC.sid = R.sid
			inner join Offerings_Has_Handles as OHH on SCC.launch_date = OHH.launch_date and SCC.course_id = OHH.course_id
			where Cust.cust_id = _cust_id and OHH.launch_date = _launch_date and OHH.course_id = _course_id and SCC.is_valid = 0
			into current_session_sid;
			-- search redeem table
			if current_session_sid is null then
				select SCC.sid from Customers as Cust 
				inner join Credit_cards as Cred on Cust.cust_id = Cred.cust_id
				inner join Buys as B on B.number = Cred.number
				inner join Redeem as R on B.number = R.number and B.package_id = R.package_id and B.date = R.buy_date
				inner join Sessions_Conducts_Consists as SCC on SCC.launch_date = R.launch_date and SCC.course_id = R.course_id and SCC.sid = R.sid
				inner join Offerings_Has_Handles as OHH on SCC.launch_date = OHH.launch_date and SCC.course_id = OHH.course_id
				where Cust.cust_id = _cust_id and OHH.launch_date = _launch_date and OHH.course_id = _course_id and SCC.is_valid = 0
				into current_session_sid;
				register_or_redeem := 1;
			end if;
			if current_session_sid is not null then
				-- register
				if register_or_redeem = 0 then
					update Register set sid = _sid where launch_date = _launch_date and course_id = _course_id and sid = current_session_sid;
					return 0;
				-- redeem
				else 
					update Redeem set sid = _sid where launch_date = _launch_date and course_id = _course_id and sid = current_session_sid;
					return 0;
				end if;
			else
				raise exception 'customer did not register any session';
			end if;
		else
			raise exception 'new session is fully booked';
		end if;
	else
		raise exception 'registration is closed';
	end if;
end;
$$ language plpgsql;

/* 
 * Q20: a customer requests to cancel a registered course session
 * launch_date + course_id is course offering identifier 
 * input: customer identifier, and course offering identifier
 * output: 0 success
 */
create or replace function cancel_registration (_cust_id int, _launch_date date, _course_id int)
returns int as $$
declare
	current_registration_deadline date;
	current_fees decimal(10, 2);
	current_session_sid int;
	current_credit_card_number varchar(20);
	current_registration_redemption_date date;
	current_package_id int;
	current_package_buy_date date;
	current_package_credit decimal(10, 2);
	register_or_redeem int; -- 0 register; 1 redeem
begin
	register_or_redeem := 0;
	-- if the cancellation is made at least 7 days before the day of the registered session
	-- find registration deadline
	select registration_deadline from Offerings_Has_Handles 
	where launch_date = _launch_date and course_id = _course_id
	into current_registration_deadline;
	if current_registration_deadline is null then
		raise exception 'course offering identifier is invlid';
	end if;
	-- precondition: a customer only registered for at most one of its sessions for each course offering, so only one record will be shown below
	-- register = register + redeem
	-- search register table
	select SCC.sid, Cred.number, R.date from Customers as Cust 
	inner join Credit_cards as Cred on Cust.cust_id = Cred.cust_id
	inner join Register as R on Cred.number = R.number
	inner join Sessions_Conducts_Consists as SCC on SCC.launch_date = R.launch_date and SCC.course_id = R.course_id and SCC.sid = R.sid
	inner join Offerings_Has_Handles as OHH on SCC.launch_date = OHH.launch_date and SCC.course_id = OHH.course_id
	where Cust.cust_id = _cust_id and OHH.launch_date = _launch_date and OHH.course_id = _course_id and SCC.is_valid = 0
	into current_session_sid, current_credit_card_number, current_registration_redemption_date;
	-- search redeem table
	if current_session_sid is null then
		select SCC.sid, Cred.number, R.date, R.package_id, R.buy_date from Customers as Cust 
		inner join Credit_cards as Cred on Cust.cust_id = Cred.cust_id
		inner join Buys as B on B.number = Cred.number
		inner join Redeem as R on B.number = R.number and B.package_id = R.package_id and B.date = R.buy_date
		inner join Sessions_Conducts_Consists as SCC on SCC.launch_date = R.launch_date and SCC.course_id = R.course_id and SCC.sid = R.sid
		inner join Offerings_Has_Handles as OHH on SCC.launch_date = OHH.launch_date and SCC.course_id = OHH.course_id
		where Cust.cust_id = _cust_id and OHH.launch_date = _launch_date and OHH.course_id = _course_id and SCC.is_valid = 0
		into current_session_sid, current_credit_card_number, current_registration_redemption_date, current_package_id, current_package_buy_date;
		register_or_redeem := 1;
	end if;
	if current_session_sid is not null then
		-- register
		if register_or_redeem = 0 then
			-- refund 90% of the paid fees for a registered course if the cancellation is made at least 7 days before the day of the registered session
			if current_registration_deadline >= current_date + interval '1 day' * 7 then
				select fees from Offerings_Has_Handles where launch_date = _launch_date and course_id = _course_id into current_fees;
				insert into Cancels values (current_date, ROUND(0.9 * current_fees, 2), null, current_session_sid, _cust_id, _launch_date, _course_id, current_registration_redemption_date);
			else
				insert into Cancels values (current_date, 0, null, current_session_sid, _cust_id, _launch_date, _course_id, current_registration_redemption_date);
			end if;
			delete from Register where launch_date = _launch_date and course_id = _course_id and sid = current_session_sid 
					and number = current_credit_card_number and date = current_registration_redemption_date; 
			return 0;
		-- redeem
		else
			-- credit an extra course session to the customer’s course package if the cancellation is made at least 7 days before the day of the registered session
			if current_registration_deadline >= current_date + interval '1 day' * 7 then
				insert into Cancels values (current_date, null, 0, current_session_sid, _cust_id, _launch_date, _course_id, current_registration_redemption_date);
				update Buys B set num_remaining_redemptions = B.num_remaining_redemptions + 1 
				where B.date = current_package_buy_date and B.number = current_credit_card_number and B.package_id = current_package_id;
			else
				select CP.price / CP.num_free_registrations from Course_packages as CP
				inner join Redeem as R on CP.package_id = R.package_id
				inner join Sessions_Conducts_Consists as SCC on R.sid = SCC.sid and R.course_id = SCC.course_id and R.launch_date = SCC.launch_date
				where SCC.launch_date = _launch_date and SCC.course_id = _course_id and SCC.sid = current_session_sid into current_package_credit;
				insert into Cancels values (current_date, null, current_package_credit, current_session_sid, _cust_id, _launch_date, _course_id, current_registration_redemption_date);
			end if;
			delete from Redeem where launch_date = _launch_date and course_id = _course_id and sid = current_session_sid 
					and number = current_credit_card_number and date = current_registration_redemption_date
					and package_id = current_package_id and buy_date = current_package_buy_date; 
			return 0;
		end if;
	else
		raise exception 'customer did not register any session';
	end if;
end;
$$ language plpgsql;

/* 
 * Q21: change the instructor for a course session
 * launch_date + course_id is course offering identifier
 * input: course offering identifier, session number, and identifier of the new instructor
 * output: 0 success
 */
create or replace function update_instructor (_launch_date date, _course_id int, _sid int, _eid int)
returns int as $$
declare
	current_session_date date;
	current_session_start_time time;
	current_session_end_time time;
	num_of_available_session_records int;
	num_of_available_instructor_records int;
begin
	num_of_available_session_records := 0;
	num_of_available_instructor_records := 0;
	select count(*) from Sessions_Conducts_Consists where launch_date = _launch_date and course_id = _course_id and sid = _sid and is_valid = 0 
			and ((date > current_date) or (date = current_date and start_time > current_time)) into num_of_available_session_records;
	-- if the course session has not yet started
	if num_of_available_session_records <> 0 then
		-- find the session date and time
		select date, start_time, end_time from Sessions_Conducts_Consists where launch_date = _launch_date and course_id = _course_id and sid = _sid and is_valid = 0 
			into current_session_date, current_session_start_time, current_session_end_time;
		-- check if instructor is available
		select count(*) from find_instructors(_course_id, current_session_date, current_session_start_time) where employeeIdentifier = _eid into num_of_available_instructor_records;
		if num_of_available_instructor_records <> 0 then
			update Sessions_Conducts_Consists set eid = _eid where launch_date = _launch_date and course_id = _course_id and sid = _sid;
			return 0;
		else
			raise exception 'eid is in invalid';
		end if;
	else
		raise exception 'instructor is not allowed to be updated';
	end if;
end;
$$ language plpgsql;
 
/* 
 * Q22: change the room for a course session
 * launch_date + course_id is course offering identifier 
 * input: course offering identifier, session number, and identifier of the new room
 * output: 0 success
 */
create or replace function update_room (_launch_date date, _course_id int, _sid int, _rid int)
returns int as $$
declare
	num_of_records int;
	current_room_seating_capacity int;
	new_room_seating_capacity int;
	num_of_registrations int;
	num_of_redemptions int;
begin
	num_of_records := 0;
	select count(*) from Sessions_Conducts_Consists where launch_date = _launch_date and course_id = _course_id and sid = _sid and is_valid = 0 
			and ((date > current_date) or (date = current_date and start_time > current_time)) into num_of_records;
	-- if the course session has not yet started
	if num_of_records <> 0 then
		select seating_capacity from Rooms where rid = _rid into new_room_seating_capacity;
		if new_room_seating_capacity is not null then
			-- the seating capacity of a course session is equal to the seating capacity of the room where the session is conducted
			-- the seating capacity of a course offering is equal to the sum of the seating capacities of its sessions
			select R.seating_capacity from Sessions_Conducts_Consists as SCC inner join Rooms as R on SCC.rid = R.rid
					where SCC.launch_date = _launch_date and SCC.course_id = _course_id and SCC.sid = _sid and SCC.is_valid = 0 into current_room_seating_capacity;
			-- the number of registrations for the session <= the seating capacity of the new room
			select count(*) from Register where launch_date = _launch_date and course_id = _course_id and sid = _sid into num_of_registrations;
			select count(*) from Redeem where launch_date = _launch_date and course_id = _course_id and sid = _sid into num_of_redemptions;
			if num_of_registrations + num_of_redemptions <= new_room_seating_capacity then 
				update Offerings_Has_Handles set seating_capacity = seating_capacity - current_room_seating_capacity + new_room_seating_capacity
						where launch_date = _launch_date and course_id = _course_id;	
				update Sessions_Conducts_Consists set rid = _rid 
						where launch_date = _launch_date and course_id = _course_id and sid = _sid and is_valid = 0;
				return 0;
			else 
				raise exception 'the seating capacity of the new room is no enougth';
			end if;
		else
			raise exception 'rid is invalid';
		end if;
	end if;
	raise exception 'session is not allowed to be updated';
end;
$$ language plpgsql;

/* 
 * Q23: remove a course session
 * launch_date + course_id is course offering identifier 
 * input: course offering identifier and session number
 * output: 0 success
 */
create or replace function remove_session (_launch_date date, _course_id int, _sid int)
returns int as $$
declare
	num_of_registrations int;
	num_of_redemptions int;
	num_of_total_records int;
	num_of_available_records int;
	max_date date;
	min_date date;
	total_seating_capacity int;
	current_target_number_registrations int;
	curs cursor for (select * from Sessions_Conducts_Consists as SCC inner join Rooms as R on R.rid = SCC.rid 
					 where SCC.launch_date = _launch_date and SCC.course_id = _course_id and SCC.is_valid = 0);
	r record;
begin
	num_of_registrations := 0;
	num_of_redemptions := 0;
	num_of_total_records := 0;
	num_of_available_records := 0;
	total_seating_capacity := 0;
	current_target_number_registrations := 0;
	-- the request must not be performed if there is at least one registration for the session
	select count(*) from Register where launch_date = _launch_date and course_id = _course_id and sid = _sid into num_of_registrations;
	select count(*) from Redeem where launch_date = _launch_date and course_id = _course_id and sid = _sid into num_of_redemptions;
	if num_of_registrations = 0 and num_of_redemptions = 0 then
		select count(*) from Sessions_Conducts_Consists where launch_date = _launch_date and course_id = _course_id and is_valid = 0 into num_of_total_records;
		select count(*) from Sessions_Conducts_Consists where launch_date = _launch_date and course_id = _course_id and sid = _sid and is_valid = 0 
				and ((date > current_date) or (date = current_date and start_time > current_time)) into num_of_available_records;
		-- if the course session has not yet started
		-- each course offering consists of one or more sessions, the course offering must still have one or more sessions after the session is removed
		if num_of_total_records > 1 and num_of_available_records <> 0 then
			update Sessions_Conducts_Consists set is_valid = 1 where launch_date = _launch_date and course_id = _course_id and sid = _sid;
			-- each course offering has a start date and an end date that is determined by the dates of its earliest and latest sessions
			--  min(date) and max(date) must not be null since num_of_records > 0
			select min(date), max(date) from Sessions_Conducts_Consists where 
					launch_date = _launch_date and course_id = _course_id and is_valid = 0 into min_date, max_date;		
			-- the seating capacity of a course session is equal to the seating capacity of the room where the session is conducted
			-- the seating capacity of a course offering is equal to the sum of the seating capacities of its sessions
			open curs;
			loop
				fetch curs into r;
				exit when not found;
				total_seating_capacity := total_seating_capacity + r.seating_capacity;
			end loop;
			close curs;
			select target_number_registrations from Offerings_Has_Handles where launch_date = _launch_date and course_id = _course_id into current_target_number_registrations;
			if current_target_number_registrations <= total_seating_capacity then
				update Offerings_Has_Handles set start_date = min_date, end_date = max_date, seating_capacity = total_seating_capacity 
						where launch_date = _launch_date and course_id = _course_id;
				return 0;
			end if;
		end if;
	end if;
	raise exception 'session is not allowed to be removed';
end;
$$ language plpgsql;

/* 
 * Q24: add a new session to a course offering
 * launch_date + course_id is course offering identifier
 * input: course offering identifier, new session number, new session day, new session start hour, instructor identifier for new session, and room identifier for new session
 * output: 0 success
 */
create or replace function update_start_end_date_and_capacity_of_course_offering() returns trigger as $$
declare
	curs cursor for (select * from Sessions_Conducts_Consists as SCC inner join Rooms as R on R.rid = SCC.rid 
					 where SCC.launch_date = NEW.launch_date and SCC.course_id = NEW.course_id and SCC.is_valid = 0);
	r record;
	max_date date;
	min_date date;
	total_seating_capacity int;
begin
	-- each course offering has a start date and an end date that is determined by the dates of its earliest and latest sessions
	select min(date), max(date) from Sessions_Conducts_Consists 
			where launch_date = NEW.launch_date and course_id = NEW.course_id and is_valid = 0 into min_date, max_date;
	if min_date is null then
		min_date := NEW.date;
	end if;
	if max_date is null then
		max_date := NEW.date;
	end if;
	-- the seating capacity of a course session is equal to the seating capacity of the room where the session is conducted
	-- the seating capacity of a course offering is equal to the sum of the seating capacities of its sessions
	total_seating_capacity := 0;
	open curs;
	loop
		fetch curs into r;
		exit when not found;
		total_seating_capacity := total_seating_capacity + r.seating_capacity;
	end loop;
	close curs;

	update Offerings_Has_Handles set start_date = min_date, end_date = max_date, seating_capacity = total_seating_capacity 
			where launch_date = NEW.launch_date and course_id = NEW.course_id;
	return null;
END;
$$ language plpgsql;

-- drop trigger if exists update_start_end_date_and_capacity_of_course_offering_trigger on Sessions_Conducts_Consists;
create trigger update_start_end_date_and_capacity_of_course_offering_trigger
after insert on Sessions_Conducts_Consists
for each row execute function update_start_end_date_and_capacity_of_course_offering();

create or replace function add_session (_launch_date date, _course_id int, _sid int, _date date, _start_time time, _eid int, _rid int)
returns int as $$
declare
	current_sid int;
	current_registration_deadline date;
	num_of_available_course_offerings int;
	num_of_available_instructor_records int;
	num_of_available_room_records int;
	current_target_number_registrations int;
begin
	current_target_number_registrations := 0;
	num_of_available_course_offerings := 0;
	num_of_available_instructor_records := 0;
	num_of_available_room_records := 0;
	-- find the latest sid of the course offering (including invalid sessions)
	select sid from Sessions_Conducts_Consists where launch_date = _launch_date and course_id = _course_id order by sid desc limit 1 into current_sid;
	if current_sid is null then
		current_sid := 0;
	end if;
	-- the sessions for a course offering are numbered consecutively starting from 1, so new_sid = current_sid + 1
	if current_sid + 1 = _sid then
		-- precondition: _date, _start_time, _rid and _eid are all valid
		-- check if instructor is available
		select count(*) from find_instructors(_course_id, _date, _start_time) where employeeIdentifier = _eid into num_of_available_instructor_records;
		if num_of_available_instructor_records = 0  then
			raise exception 'eid in invalid';
		end if;
		-- check if room is available
		select count(*) from find_rooms(_date, _start_time, 1) where rid = _rid into num_of_available_room_records;
		if num_of_available_room_records = 0  then
			raise exception 'rid in invalid';
		end if;
		-- is_valid defalut = 0
		insert into Sessions_Conducts_Consists (sid, launch_date, start_time, end_time, date, rid, eid, course_id) 
				values (_sid, _launch_date, _start_time, _start_time + interval '1 hour', _date, _rid, _eid, _course_id);
	else
		raise exception 'sid is invalid';
	end if;
	return 0;
end;
$$ language plpgsql;


/* 
 * Q25: at the end of the month to pay salaries to employees.
 * status: 0 full-time; 1 part-time
 * output: employee identifier, name, status (either part-time or full-time), number of work days for the month, 
 * number of work hours for the month, hourly rate, monthly salary, and salary amount paid.
 */
create or replace function pay_salary () 
returns table(eid int, name varchar(100), status int, num_work_days int, num_work_hours int,
			  hourly_rate decimal(10, 2), monthly_salary decimal(10, 2), amount decimal(10, 2)) as $$
declare
	r record;
	num_of_payment_records int;
begin
	num_of_payment_records := 0;
	for r in select * from Employees order by eid asc -- sorted in ascending order
	loop
		select count(*) from Pay_slips_For where Pay_slips_For.eid = r.eid and extract(month from payment_date) = extract(month from current_date) into num_of_payment_records;
		if num_of_payment_records = 0 then
			return query select * from pay_salary(r.eid);
		end if;
	end loop;
	return;
end;
$$ language plpgsql;

create or replace function pay_salary (_eid int) 
returns table(r_eid int, r_name varchar(100), r_status int, r_num_work_days int, r_num_work_hours int,
			  r_hourly_rate decimal(10, 2), r_monthly_salary decimal(10, 2), r_amount decimal(10, 2)) as $$
declare
	r record;
	number_of_days int;
	first_work_day int;
	last_work_day int;
	total_duration int;
	current_eid int;
	current_name varchar(100);
	current_monthly_salary decimal(10, 2);
	current_hourly_rate decimal(10, 2);
	current_join_date date;
	current_depart_date date;
begin
	-- pay salaries at the end of the month, so can use NOW()
	number_of_days := DATE_PART('days', DATE_TRUNC('month', NOW()) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL);
	first_work_day := 1;
	last_work_day := number_of_days;
	if current_eid is null then
		select FE.eid, E.name, FE.monthly_salary from Full_time_Emp as FE inner join Employees as E 
		on FE.eid = E.eid where FE.eid = _eid into current_eid, current_name, current_monthly_salary;
		if current_eid is not null then
			select join_date, depart_date from Employees where eid = _eid into current_join_date, current_depart_date; -- This record must exist
			-- same year same month
			if extract(year from current_date) = extract(year from current_join_date) and 
					extract(month from current_date) = extract(month from current_join_date) then
				first_work_day := extract(day from current_join_date);
			end if;
			-- departed
			if current_depart_date is not null then
				last_work_day := extract(day from current_depart_date);
			end if;
			insert into Pay_slips_For (amount, num_work_days, eid) values 
					(ROUND(current_monthly_salary * ((last_work_day - first_work_day + 1) * 1.0 / number_of_days), 2),
					(last_work_day - first_work_day + 1), _eid) returning * into r;
			return query select current_eid, current_name::varchar(100), 0, r.num_work_days, r.num_work_hours, 
					current_hourly_rate::decimal(10, 2), current_monthly_salary::decimal(10, 2), r.amount::decimal(10, 2);
			return;
		end if;
	end if;
	if current_eid is null then
		select PE.eid, E.name, PE.hourly_rate from Part_time_Emp as PE inner join Employees as E 
		on PE.eid = E.eid where PE.eid = _eid into current_eid, current_name, current_hourly_rate;
		if current_eid is not null then
			-- total work hours within current year and crruent month
			select case when sum(duration) is null then 0 else sum(duration) end 
				from (select extract(epoch from (end_time - start_time))::integer as duration 
				from Sessions_Conducts_Consists where eid = _eid and is_valid = 0
				and extract(year from date) = extract(year from current_date) 
				and extract(month from date) = extract(month from current_date)) as durations into total_duration;
			insert into Pay_slips_For (amount, num_work_hours, eid) values 
					(ROUND(ceil(total_duration * 1.0 / 60 / 60) * current_hourly_rate, 2),
					ceil(total_duration * 1.0 / 60 / 60), _eid) returning * into r;
			return query select current_eid, current_name::varchar(100), 1, r.num_work_days, r.num_work_hours, 
					current_hourly_rate::decimal(10, 2), current_monthly_salary::decimal(10, 2), r.amount::decimal(10, 2);
			return;
		end if;
	end if;
	raise exception 'eid is invalid';
end;
$$ language plpgsql;

/* 
 * Q26: identify potential course offerings that could be of interest to inactive customers
 * output: customer identifier, customer name, course area A that is of interest to the customer, course identifier of a course C in area A, 
 * course title of C, launch date of course offering of course C that still accepts registrations, course offering’s registration deadline, 
 * and fees for the course offering. 
 */
create or replace function promote_courses ()
returns table(cust_id int, cust_name varchar(100), course_area_name varchar(100), course_id int, title varchar(100), 
			  launch_date date, registration_deadline date, fees decimal(10, 2)) as $$
declare
    -- inactive customer
	curs cursor for (select CS.cust_id from 
					 ((select distinct Customers.cust_id from Customers -- If a customer has not yet registered for any course offering
					   except
					   select distinct C.cust_id from Credit_cards as C inner join Register as R on C.number = R.number 
					   except
					   select distinct C.cust_id from Credit_cards as C inner join Redeem as R on C.number = R.number
					   except
					   select distinct Cancels.cust_id from Cancels)
					  union
					  -- A customer is classified as an active customer if the customer has registered for some course offering in the last six months (inclusive of the current month); 
					  -- otherwise, the customer is considered to be inactive customer. 
					  ((select distinct C.cust_id from Credit_cards as C inner join Register as R on C.number = R.number) 
					  except
					  (select distinct C.cust_id from Credit_cards as C inner join Register as R on C.number = R.number 
					   where (R.date - interval '1 day' * extract(day from R.date) + interval '1 month' * 6) >= current_date))
					  union
					  ((select distinct C.cust_id from Credit_cards as C inner join Redeem as R on C.number = R.number) 
					  except
					  (select distinct C.cust_id from Credit_cards as C inner join Redeem as R on C.number = R.number 
					   where (R.date - interval '1 day' * extract(day from R.date) + interval '1 month' * 6) >= current_date))
					  union
					  ((select distinct Cancels.cust_id from Cancels) 
					  except
					  (select distinct Cancels.cust_id from Cancels
					   where (register_date - interval '1 day' * extract(day from register_date) + interval '1 month' * 6) >= current_date))
					 ) as CS order by CS.cust_id asc);
	r record;
begin
	-- sorted in ascending order of customer identifier
	open curs;
	loop
		fetch curs into r;
		exit when not found;
		return query select * from promote_courses(r.cust_id);
	end loop;
	close curs;
	return;
end;
$$ language plpgsql;

create or replace function promote_courses (_cust_id int)
returns table(cust_id int, cust_name varchar(100), course_area_name varchar(100), course_id int, title varchar(100), 
			  launch_date date, registration_deadline date, fees decimal(10, 2)) as $$
declare
	num_of_top_3_course_offering int;
begin
	num_of_top_3_course_offering := 0;
	select count(*) from top_3_course_offerings(_cust_id) into num_of_top_3_course_offering;
		-- sorted in ascending order of course offering’s registration deadline
	if num_of_top_3_course_offering <> 0 then
		-- cross product: combine Customers records and Course_Info records
		return query select distinct Customers.cust_id, Customers.name as cust_name, Promote_Course_Info.name as course_area_name, Promote_Course_Info.course_id, 
				Promote_Course_Info.title, Promote_Course_Info.launch_date, Promote_Course_Info.registration_deadline, Promote_Course_Info.fees from Customers, 
				-- find all the course offerings under these course areas
				(select distinct CI1.course_id, CI1.title, CM1.name, OHH1.launch_date, OHH1.registration_deadline, OHH1.fees from Offerings_Has_Handles as OHH1 
				inner join Courses_In as CI1 on OHH1.course_id = CI1.course_id
				inner join Course_areas_Manages as CM1 on CM1.name = CI1.name
				inner join 
				-- find all the course areas that the three most recent course offerings in these course areas registered by C
				(select distinct CM2.name from Courses_In as CI2 
				 		inner join (select * from top_3_course_offerings(_cust_id)) as top3COR on top3COR.course_id = CI2.course_id
						inner join Course_areas_Manages as CM2 on CI2.name = CM2.name) as Course_Info on CI1.name = Course_Info.name
				-- filter out the course offering still accepts registrations
				where OHH1.registration_deadline <= current_date)
				as Promote_Course_Info	
				where Customers.cust_id = _cust_id order by Promote_Course_Info.registration_deadline asc;
		return;
	else
		-- cross product: combine Customers records and Course_Info records
		return query select distinct Customers.cust_id, Customers.name as cust_name, Course_Info.name as course_area_name, Course_Info.course_id, 
				Course_Info.title, Course_Info.launch_date, Course_Info.registration_deadline, Course_Info.fees from Customers, 
				-- 1. if a customer has not yet registered for any course offering, we assume that every course area is of interest to that customer
				-- 2. filter out the course offering still accepts registrations
				(select distinct CM.name, CI.course_id, CI.title, OHH.launch_date, OHH.registration_deadline, OHH.fees from Courses_In as CI 
				 		inner join Offerings_Has_Handles as OHH on OHH.course_id = CI.course_id
						inner join Course_areas_Manages as CM on CI.name = CM.name where OHH.registration_deadline <= current_date) as Course_Info
				 where Customers.cust_id = _cust_id order by Course_Info.registration_deadline asc;
		return;
	end if;
end;
$$ language plpgsql;

create or replace function top_3_course_offerings (_cust_id int)
returns table(course_id int, launch_date date, date date, registration_deadline date, fees decimal(10, 2)) as $$
begin
	-- the three most recent course offerings registered by the customer
	-- register
	return query select RR.course_id, RR.launch_date, RR.date, RR.registration_deadline, RR.fees from
	(select distinct OHH.course_id, OHH.launch_date, R.date, OHH.registration_deadline, OHH.fees from Credit_cards as C
			inner join Register as R on C.number = R.number
			inner join Sessions_Conducts_Consists as SCC on R.sid = SCC.sid and R.course_id = SCC.course_id and R.launch_date = SCC.launch_date 
			inner join Offerings_Has_Handles as OHH on SCC.course_id = OHH.course_id and SCC.launch_date = OHH.launch_date 
			where C.cust_id = _cust_id and SCC.is_valid = 0
	union
	-- redeem
	select distinct OHH.course_id, OHH.launch_date, R.date, OHH.registration_deadline, OHH.fees from Credit_cards as C
			inner join Redeem as R on C.number = R.number
			inner join Sessions_Conducts_Consists as SCC on R.sid = SCC.sid and R.course_id = SCC.course_id and R.launch_date = SCC.launch_date 
			inner join Offerings_Has_Handles as OHH on SCC.course_id = OHH.course_id and SCC.launch_date = OHH.launch_date 
			where C.cust_id = _cust_id and SCC.is_valid = 0
	union
	-- cancel
	select distinct OHH.course_id, OHH.launch_date, R.register_date, OHH.registration_deadline, OHH.fees from Customers as C
			inner join Cancels as R on C.cust_id = R.cust_id
			inner join Sessions_Conducts_Consists as SCC on R.sid = SCC.sid and R.course_id = SCC.course_id and R.launch_date = SCC.launch_date 
			inner join Offerings_Has_Handles as OHH on SCC.course_id = OHH.course_id and SCC.launch_date = OHH.launch_date 
			where C.cust_id = _cust_id and SCC.is_valid = 0
	) as RR
	order by date desc limit 3;
	return;
end;
$$ language plpgsql;

/* 
 * Q27: find the top N course packages in terms of the total number of packages sold for this year (i.e., the package’s start date is within this year)
 * input: a positive integer number N
 * output: a table of records consisting of the following information for each popular course: course identifier, course title, course area, 
 * number of offerings this year, and number of registrations for the latest offering this year
 */
create or replace function top_packages (N int)
returns table(
	package_id int,
	num_free_registrations int,
	price decimal(10, 2),
	sale_start_date date,
	sale_end_date date,
	num_package_sold int
)
as $$
declare
nth_cnt int;
begin
	create or replace temp view Buys_stat as (
		select package_id, cast (count(*) as int) as cnt 
        from Buys
		where (extract (year from current_date)) = (extract (year from date))
        group by package_id
		order by cnt desc
	);
	select cnt from Buys_stat order by cnt desc offset (N - 1) limit 1 into nth_cnt;
	    return query (select * from
		((select R.package_id, R.num_free_registrations, R.price, R.sale_start_date, R.sale_end_date, R.cnt
        from (Course_packages natural join Buys_stat) as R
		order by R.cnt desc, R.price desc
		limit (N - 1))
		union
		(select R.package_id, R.num_free_registrations, R.price, R.sale_start_date, R.sale_end_date, R.cnt
        	from (Course_packages natural join Buys_stat) as R
			where R.cnt = (nth_cnt)
		))as RR order by RR.cnt desc, RR.price desc);
end;
$$ language plpgsql;

/* 
 * Q28: find the popular courses offered this year (i.e., start date is within this year)
 * output: a table of records consisting of the following information for each popular course: course identifier, 
 * course title, course area, number of offerings this year, and number of registrations for the latest offering this year. 
 */
create or replace function popular_courses()
returns table(
    out_course_id int,
    out_course_title varchar(100),
    out_course_area varchar(100),
    out_num_offerings bigint,
    out_num_latest_offering_register bigint
) as $$
begin
	-- A course is popular if the course has at least two offerings this year, and for every pair of offerings of the course this year, 
	-- the offering with the later start date has a higher number of registrations than that of the offering with the earlier start date.
	-- 1. must be registered, all 0 registration records cannot meet the requirement of "higher number" above
    return query 
    with register_num as (
        select course_id, launch_date, count(*) as register_count from Register natural join Offerings_Has_Handles
        where extract(year from Offerings_Has_Handles.start_date) = extract(year from CURRENT_DATE)
        group by course_id, launch_date
    ),
    redeem_num as (
        select count(*) as redeem_count, course_id, launch_date from Redeem natural join Offerings_Has_Handles
        where extract(year from Offerings_Has_Handles.start_date) = extract(year from CURRENT_DATE)
        GROUP BY course_id, launch_date
    ),
    total_num as (
        select course_id, launch_date, start_date, COALESCE(register_count, 0) + COALESCE(redeem_count, 0) as total_count
        from Offerings_Has_Handles natural left join register_num natural left join redeem_num
    ),
	offering_count as (
		select course_id, count(*) as num_offerings
        from Offerings_Has_Handles
        group by Course_id
	),
	temp as (
        select course_id, max(total_count) as num_latest_offering_register from total_num
        where course_id <> all(
			-- In each course, the combination of all course offerings satisfy:
			-- the offering with the later start date has a higher number of registrations than that of the offering with the earlier start date
            select distinct T2.course_id 
            from total_num T1, total_num T2
			-- excluding the cases below
			-- only select T1.start_date < T2.start_date and T1.total_count < T2.total_count
            where (T1.course_id = T2.course_id and T1.launch_date <> T2.launch_date) and
                ((T1.start_date < T2.start_date
                and T1.total_count >= T2.total_count)
				or
				(T1.start_date >= T2.start_date
                and T1.total_count < T2.total_count)
				or
				(T1.start_date >= T2.start_date
                and T1.total_count = T2.total_count)
				or
				(T1.start_date = T2.start_date
                and T1.total_count <= T2.total_count))
        )
        group by course_id
        having count(*) >= 2
    )
	-- select * from temp;
    select C.course_id, C.title, C.name, O.num_offerings, T.num_latest_offering_register
    from Courses_In C natural join temp T natural join offering_count O
    order by num_latest_offering_register desc, Course_id asc;
end;
$$ language plpgsql;

/* 
 * Q29: view a monthly summary report of the company’s sales and expenses for a specified number of months.
 * input: a number of months (say N)
 * output: a table of records consisting of the following information for each of the last N months (starting from the current month): 
 * month and year, total salary paid for the month, total amount of sales of course packages for the month, total registration fees paid via credit card payment for the month, total amount of refunded registration fees (due to cancellations) for the month, and total number of course registrations via course package redemptions for the month.
 */
create or replace function view_summary_report(in_num_months int)
returns table (
    _out_year int,
    _out_month int,
    _total_salary decimal(10, 2),
    _total_sale_packages decimal(10, 2),
    _total_register_fees decimal(10, 2),
    _total_refund_fees decimal(10, 2),
    _total_course_redeem int
) as $$
declare
    out_year int;
    out_month int;
    total_salary decimal(10, 2);
    total_sale_packages decimal(10, 2);
    total_register_fees decimal(10, 2);
    total_refund_fees decimal(10, 2);
    total_course_redeem int;
	is_end int;
	count_months int;
begin
    out_month := extract(month from CURRENT_DATE);
    out_year := extract(year from CURRENT_DATE);
	count_months := 1;
	is_end := 0;
	while is_end = 0
    loop
        select case when sum(amount) is not null then sum(amount) else 0 end into total_salary from Pay_slips_For
        where extract(year from payment_date) = out_year
            	and extract(month from payment_date) = out_month;
        
        select case when sum(price) is not null then sum(price) else 0 end into total_sale_packages
        from Course_packages natural join Buys
        where extract(year from date) = out_year
            	and extract(month from date) = out_month;

        select case when sum(fees) is not null then sum(fees) else 0 end into total_register_fees
        from Register natural join Offerings_Has_Handles
        where extract(year from date) = out_year
            	and extract(month from date) = out_month;

        select case when sum(refund_amt) is not null then sum(refund_amt) else 0 end into total_refund_fees
        from Cancels
        where extract(year from date) = out_year 
				and extract(month from date) = out_month;
		
		select count(*) into total_course_redeem
        from Redeem
        where extract(year from date) = out_year
            and extract(month from date) = out_month;
		
		if (out_month = null and out_year = null and total_salary = null and total_sale_packages = null and total_register_fees = null 
				and total_refund_fees = null and total_course_redeem = null) or (count_months > in_num_months) then
			is_end := 1;
		else
			return query select out_year, out_month, total_salary, total_sale_packages, total_register_fees, total_refund_fees, total_course_redeem;	
		end if;
		
		if out_month <> 1 then
        	out_month := out_month - 1;
		else 
			out_year := out_year - 1;
			out_month := 12;
		end if;
		count_months := count_months + 1;
    end loop;
	return;
end;
$$ language plpgsql;

/* 
 * Q30: view a report on the sales generated by each manager
 */
create or replace function view_manager_report()
returns table(
    out_manager_name varchar(100),
    out_total_num_course_area int,
    out_total_num_course_off int,
    out_total_net_sale_fee decimal(10, 2),
    out_most_net_sale_title text
) as $$
declare
    curs cursor for(select eid, (select name from Employees where M.eid = eid) as Ins_name from Managers M order by Ins_name asc);
    r RECORD;
	current_eid int;
begin
    open curs;
    loop
        fetch curs into r;
        exit when not found;
		current_eid := r.eid;
		
		-- manager name
        out_manager_name := (select name from Employees where r.eid = eid);

		-- total number of course areas that are managed by the manager
        select count(distinct name) from (select * from course_info()) as CI 
		where CI.eid = r.eid into out_total_num_course_area;
		
		-- total number of course offerings that ended this year that are managed by the manager
		select distinct count(*) from (select * from course_info()) as CI
        where CI.eid = r.eid and (extract(year from CI.end_date) = extract(year from current_date)) into out_total_num_course_off;

		-- total net registration fees for all the course offerings that ended this year that are managed by the manager
        select total_net_registration_fees from total_net_registration_fees(r.eid) into out_total_net_sale_fee;

		-- the course offering title (i.e., course title) that has the highest total net registration fees among all the 
		-- course offerings that ended this year that are managed by the manager
		-- if there are ties, list all these top course offering titles
		select array_agg(title) from highest_net_registration_fees(r.eid) 
		where net_registration_fees = (select net_registration_fees from highest_net_registration_fees(r.eid) 
									   order by net_registration_fees desc limit 1)
		into out_most_net_sale_title;
        return next;
    end loop;
    close curs;
end;
$$ language plpgsql;

create or replace function course_info ()
returns table(
	course_id int,
	name varchar(100),
	eid int,
	duration int,
	title varchar(100),
	launch_date date,
	start_date date,
	end_date date,
	target_number_registrations int,
	seating_capacity int,
	fees decimal(10, 2)
) as $$
begin
	return query select OHH.course_id, CM.name, CM.eid, CI.duration, CI.title, OHH.launch_date, 
	OHH.start_date, OHH.end_date, OHH.target_number_registrations, OHH.seating_capacity, OHH.fees
	from Course_areas_Manages as CM inner join Courses_In as CI on CM.name = CI.name
	inner join Offerings_Has_Handles as OHH on OHH.course_id = CI.course_id;
	return;
end;
$$ language plpgsql;

create or replace function total_net_registration_fees (_eid int)
returns decimal(10, 2) as $$
declare
	current_sum_fees decimal(10, 2);
begin
	current_sum_fees := 0;
	-- the sum of the total registration fees paid for the course offering via credit card payment (excluding any refunded fees due to cancellations)
	select 
	(
		select case when sum(OHH.fees) is not null then sum(OHH.fees) else 0 end as register_fees from Register as R 
		inner join Sessions_Conducts_Consists as SCC on R.sid = SCC.sid and R.course_id = SCC.course_id and R.launch_date = SCC.launch_date 
		inner join Offerings_Has_Handles as OHH on SCC.course_id = OHH.course_id and SCC.launch_date = OHH.launch_date 
		inner join Courses_In as CI on OHH.course_id = CI.course_id
		inner join Course_areas_Manages as CM on CI.name = CM.name
		where CM.eid = _eid and (extract(year from OHH.end_date) = extract(year from current_date)) and SCC.is_valid = 0
	)
	+
	-- the redemption registration fees for a course offering refers to the registration fees for a course offering that is paid via a redemption from a course package
	-- this registration fees is given by the price of the course package divided by the number of sessions included in the course package (rounded down to the nearest dollar)
	(
		select case when sum(RF.redeem_fee) is not null then sum(RF.redeem_fee) else 0 end as redeem_fees from 
		(select CP.price / CP.num_free_registrations as redeem_fee from Course_packages as CP
		inner join Redeem as R on CP.package_id = R.package_id
		inner join Sessions_Conducts_Consists as SCC on R.sid = SCC.sid and R.course_id = SCC.course_id and R.launch_date = SCC.launch_date 
		inner join Offerings_Has_Handles as OHH on SCC.course_id = OHH.course_id and SCC.launch_date = OHH.launch_date 
		inner join Courses_In as CI on OHH.course_id = CI.course_id
		inner join Course_areas_Manages as CM on CI.name = CM.name
		where CM.eid = _eid and (extract(year from OHH.end_date) = extract(year from current_date)) and SCC.is_valid = 0) as RF
	)
	+
	(
		select case when sum(cancel_fee) is not null then sum(cancel_fee) else 0 end as cancel_fees from 
		(select 
		 	(case when R.refund_amt is not null 
		 		then OHH.fees - R.refund_amt
		 		else R.package_credit end) as cancel_fee from Cancels as R 
		inner join Offerings_Has_Handles as OHH on R.launch_date = OHH.launch_date and R.course_id = OHH.course_id
		inner join Courses_In as CI on OHH.course_id = CI.course_id
		inner join Course_areas_Manages as CM on CI.name = CM.name
		where CM.eid = _eid and (extract(year from OHH.end_date) = extract(year from current_date))) as CF
	)
	as sum_fees into current_sum_fees;
	return current_sum_fees;
end;
$$ language plpgsql;

create or replace function highest_net_registration_fees (_eid int)
returns table(
	course_id int,
	title varchar(100),
	register_fees decimal(10, 2),
	redeem_fees decimal(10, 2),
	cancel_fees decimal(10, 2),
	net_registration_fees decimal(10, 2)
) as $$
begin
	return query
	-- the sum of the total registration fees paid for the course offering via credit card payment (excluding any refunded fees due to cancellations)
	select 
		(case when RF1.course_id is null then 
			case when RF2.course_id is null then 
		 		CF2.course_id else RF2.course_id end
			else RF1.course_id end),
		(case when RF1.course_id is null then 
			case when RF2.course_id is null then 
		 		CF2.title else RF2.title end
			else RF1.title end),
		(case when RF1.register_fees is not null then RF1.register_fees else 0 end),
		(case when RF2.redeem_fees is not null then RF2.redeem_fees else 0 end),
		(case when CF2.cancel_fees is not null then CF2.cancel_fees else 0 end),
		(case when RF1.register_fees is not null then RF1.register_fees else 0 end)
		+ (case when RF2.redeem_fees is not null then RF2.redeem_fees else 0 end)
		- (case when CF2.cancel_fees is not null then CF2.cancel_fees else 0 end) as net_registration_fees from (
		select case when sum(OHH.fees) is not null then sum(OHH.fees) else 0 end as register_fees, OHH.course_id, 
		(select Courses_In.title from Courses_In where Courses_In.course_id = OHH.course_id) from Register as R 
		inner join Offerings_Has_Handles as OHH on R.launch_date = OHH.launch_date and R.course_id = OHH.course_id
		inner join Courses_In as CI on OHH.course_id = CI.course_id
		inner join Course_areas_Manages as CM on CI.name = CM.name
		where CM.eid = _eid and (extract(year from OHH.end_date) = extract(year from current_date))
		group by OHH.course_id) as RF1
		-- the redemption registration fees for a course offering refers to the registration fees for a course offering that is paid via a redemption from a course package
		-- this registration fees is given by the price of the course package divided by the number of sessions included in the course package (rounded down to the nearest dollar)
		full outer join (
		select case when sum(RF3.redeem_fee) is not null then sum(RF3.redeem_fee) else 0 end as redeem_fees, RF3.course_id, 
		(select Courses_In.title from Courses_In where Courses_In.course_id = RF3.course_id) from
		(select CP.price / CP.num_free_registrations as redeem_fee, OHH.course_id from Course_packages as CP
		inner join Redeem as R on CP.package_id = R.package_id
		inner join Sessions_Conducts_Consists as SCC on R.sid = SCC.sid and R.course_id = SCC.course_id and R.launch_date = SCC.launch_date 
		inner join Offerings_Has_Handles as OHH on SCC.course_id = OHH.course_id and SCC.launch_date = OHH.launch_date 
		inner join Courses_In as CI on OHH.course_id = CI.course_id
		inner join Course_areas_Manages as CM on CI.name = CM.name
		where CM.eid = _eid and (extract(year from OHH.end_date) = extract(year from current_date)) and SCC.is_valid = 0) as RF3
		group by RF3.course_id) as RF2 on RF1.course_id = RF2.course_id
		full outer join (
		select case when sum(cancel_fee) is not null then sum(cancel_fee) else 0 end as cancel_fees, CF.course_id,
		(select Courses_In.title from Courses_In where Courses_In.course_id = CF.course_id) from 
		(select (case when R.refund_amt is not null 
		 		then OHH.fees - R.refund_amt
		 		else R.package_credit end) as cancel_fee, OHH.course_id from Cancels as R 
		inner join Offerings_Has_Handles as OHH on R.launch_date = OHH.launch_date and R.course_id = OHH.course_id
		inner join Courses_In as CI on OHH.course_id = CI.course_id
		inner join Course_areas_Manages as CM on CI.name = CM.name
		where CM.eid = _eid and (extract(year from OHH.end_date) = extract(year from current_date))) as CF
		group by CF.course_id) as CF2 on RF2.course_id = CF2.course_id;
	return;
end;
$$ language plpgsql;