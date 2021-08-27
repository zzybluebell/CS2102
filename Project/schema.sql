-- 3NF?

drop table if exists Customers, Credit_cards, Course_packages, Rooms, Courses_In, Course_areas_Manages,
Offerings_Has_Handles, Sessions_Conducts_Consists, Register, Cancels, Buys, Redeem, Employees, Pay_slips_For,
Full_time_Emp, Managers, Administrators, Part_time_Emp, Instructors, Specializes, Part_time_instructors, Full_time_instructors
cascade;

-- checked
create table Employees (
	eid SERIAL primary key,
	phone char(8) unique not null check ((phone like '9%') or (phone like '8%') or (phone like '6%')),
	name varchar(100) not null,
	address text not null,
	email varchar(255) unique not null check (email like '%@%'),
	depart_date date check ((depart_date >= '2000-01-01' and depart_date <= '2099-12-31') or depart_date is null),
	join_date date not null check (join_date >= '2000-01-01' and join_date <= '2099-12-31')
);

-- checked
-- Each part-time instructor must not teach more than 30 hours for each month function check
create table Pay_slips_For (
	payment_date date check (payment_date = current_date) default current_date,
	amount decimal(10, 2) not null check (amount >= 0),
	num_work_hours int check (num_work_hours >= 0 and num_work_hours <= 744),
	num_work_days int check (num_work_days >= 0 and num_work_days <= 31),
	eid int,
	primary key(payment_date, eid),
	check ((num_work_hours is not null and num_work_days is null) or (num_work_days is not null and num_work_hours is null)),
	constraint Pay_slips_eid foreign key(eid) references Employees on delete cascade on update cascade
);

-- checked
create table Full_time_Emp (
	eid int primary key,
	monthly_salary decimal(10, 2) not null check (monthly_salary >= 0),
	constraint Full_time_Emp_eid foreign key(eid) references Employees on delete cascade on update cascade
);

-- checked
create table Managers (
	eid int primary key,
	constraint Managers_eid foreign key(eid) references Full_time_Emp on delete cascade on update cascade
);

-- checked
create table Administrators (
	eid int primary key,
	constraint Administrators_eid foreign key(eid) references Full_time_Emp on delete cascade on update cascade
);

-- checked
create table Part_time_Emp (
	eid int primary key,
	hourly_rate decimal(10, 2) not null check (hourly_rate >= 0),
	constraint Part_time_Emp_eid foreign key(eid) references Employees on delete cascade on update cascade
);

-- checked
create table Instructors (
	eid int primary key,
	constraint Instructors_eid foreign key(eid) references Employees on delete cascade on update cascade
);

-- checked
create table Part_time_instructors (
	eid int primary key references Instructors on delete cascade on update cascade references Part_time_Emp on delete cascade on update cascade
);

-- checked
create table Full_time_instructors (
	eid int primary key references Instructors on delete cascade on update cascade references Full_time_Emp on delete cascade on update cascade
);

-- checked
create table Customers (
	cust_id SERIAL primary key,
	address text not null,
	phone char(8) unique not null check ((phone like '9%') or (phone like '8%') or (phone like '6%')),
	name varchar(100) not null,
	email varchar(255) unique not null check (email like '%@%')
);

-- checked
create table Credit_cards (
	number varchar(20) primary key check (length(number) >= 13),
	expiry_year int not null check (expiry_year >= extract(year from current_date) and expiry_year <= 2099),
	expiry_month int not null check ((expiry_year = extract(year from current_date) and expiry_month >= extract(month from current_date) and expiry_month <= 12) 
									 or (expiry_year > extract(year from current_date) and expiry_month >= 1 and expiry_month <= 12)),
	CVV varchar(4) not null,
	from_date date not null check (from_date = current_date) default current_date,
	cust_id int not null,
	constraint Credit_card_custid foreign key(cust_id) references Customers
);

-- checked
create table Course_packages (
	package_id SERIAL primary key,
	sale_start_date date not null check (sale_start_date >= '2000-01-01' and sale_start_date <= '2099-12-31' and sale_start_date <= sale_end_date),
	num_free_registrations int not null check (num_free_registrations >= 0),
	sale_end_date date not null check (sale_end_date >= current_date and sale_end_date <= '2099-12-31' and sale_start_date <= sale_end_date),
	name varchar(100) not null,
	price decimal(10, 2) not null check (price >= 0)
);

-- checked
create table Rooms (
	rid int primary key,
	location text not null,
	seating_capacity int not null check (seating_capacity >= 0)
);

-- checked
create table Course_areas_Manages (
	name varchar(100) primary key check (length(name) > 0),
	eid int not null,
	constraint Course_areas_Manages_eid foreign key(eid) references Managers
);

-- checked
-- some columns are nullable
create table Courses_In (
	course_id SERIAL primary key,
	duration int not null check (duration >= 0),
	description text,
	title varchar(100) not null check (length(title) > 0),
	name varchar(100) not null check (length(title) > 0),
	constraint Courses_In_name foreign key(name) references Course_areas_Manages
);

-- checked
-- some columns are nullable
-- seating_capacity need to be checked in function
-- target_number_registrations need to be checked in function
-- The registration deadline for a course offering must be at least 10 days before its start date
-- set deferred for adding new sessions
create table Offerings_Has_Handles (
	launch_date date check (launch_date >= '2000-01-01' and launch_date <= '2099-12-31' and registration_deadline >= launch_date),
	course_id int,
	start_date date not null check (start_date >= current_date and start_date <= '2099-12-31' and start_date <= end_date
								   and registration_deadline + interval '1 day' * 10 <= start_date),
	end_date date not null check (end_date >= current_date and end_date <= '2099-12-31' and start_date <= end_date),
	registration_deadline date not null check (registration_deadline >= current_date and registration_deadline <= '2099-12-31'
											  and registration_deadline + interval '1 day' * 10 <= start_date and registration_deadline >= launch_date),
	target_number_registrations int not null check (target_number_registrations >= 0 and seating_capacity >= target_number_registrations),
	seating_capacity int not null check (seating_capacity >= 0 and seating_capacity >= target_number_registrations),
	fees decimal(10, 2) not null check (fees >= 0),
	eid int not null,
	primary key(launch_date, course_id),
	constraint Offerings_course_id foreign key(course_id) references Courses_In on delete cascade on update cascade,
	constraint Offerings_eid foreign key(eid) references Administrators
);

-- checked
-- is_valid: 0 valid; 1 invalid
create table Sessions_Conducts_Consists (
	sid int,
	launch_date date check (launch_date >= '2000-01-01' and launch_date <= '2099-12-31' and date >= launch_date),
	start_time time not null check (((start_time >= '09:00' and start_time <= '11:00') or (start_time >= '14:00' and start_time <= '17:00'))
									and extract(minute from start_time) = 0 and extract(second from start_time) = 0 and (start_time <= end_time)),
	end_time time not null check (end_time = start_time + interval '1 hour' and start_time <= end_time),
	date date not null check ((extract(dow from date) in (1, 2, 3, 4, 5)) and (date >= launch_date)),
	rid int not null,
	eid int not null,
	course_id int,
	is_valid int not null check (is_valid in (0, 1)) default 0,
	primary key(sid, launch_date, course_id),
	unique(launch_date, course_id, date, start_time),
	unique(date, start_time, rid),
	constraint Sessions_Conducts_Consists_rid foreign key(rid) references Rooms,
	constraint Sessions_Conducts_Consists_eid foreign key(eid) references Instructors,
	constraint Sessions_Conducts_Consists_course_id_launch_date foreign key(launch_date, course_id) references Offerings_Has_Handles on delete cascade on update cascade
);

-- checked
-- need to make sure a customer (not credit card) can register for at most one of its sessions before its registration deadline?
-- check register and redeem only store one record for each registration
create table Register (
	date date check (date = current_date and date >= launch_date) default current_date,
	number varchar(20),
	sid int,
	launch_date date check (launch_date >= '2000-01-01' and launch_date <= '2099-12-31' and date >= launch_date),
	course_id int,
	primary key(date, number, sid, launch_date, course_id),
	constraint Register_sid_launch_date_course_id foreign key(sid, launch_date, course_id) references Sessions_Conducts_Consists,
	constraint Register_number foreign key(number) references Credit_cards
);

-- checked
-- credit an extra course session to the customer’s course package if the cancellation is made at least 7 days before the day of the registered session
-- otherwise, there will no refund for a late cancellation
create table Cancels (
	date date check (date = current_date) default current_date,
	refund_amt decimal(10, 2) check (refund_amt >= 0),
	package_credit decimal(10, 2) check (package_credit >= 0), -- record no refund
	sid int,
	cust_id int,
	launch_date date check (launch_date >= '2000-01-01' and launch_date <= '2099-12-31'),
	course_id int,
	register_date date not null check (register_date >= '2000-01-01' and register_date <= '2099-12-31' and register_date >= launch_date),
	primary key(date, cust_id, sid, launch_date, course_id),
	check ((refund_amt is not null and package_credit is null) or (refund_amt is null and package_credit is not null)),
	constraint Cancels_sid_launch_date_course_id foreign key(sid, launch_date, course_id) references Sessions_Conducts_Consists,
	constraint Cancels_cust_id foreign key(cust_id) references Customers
);

-- checked
create table Buys (
	date date check (date = current_date) default current_date,
	number varchar(20),
	package_id int,
	num_remaining_redemptions int not null check (num_remaining_redemptions >= 0),
	primary key(date, number, package_id),
	constraint Buys_number foreign key(number) references Credit_cards,
	constraint Buys_package_id foreign key(package_id) references Course_packages
);

-- checked
create table Redeem (
	date date check (date = current_date) default current_date,
	buy_date date,
	number varchar(20),
	package_id int,
	sid int,
	launch_date date check (launch_date >= '2000-01-01' and launch_date <= '2099-12-31'),
	course_id int,
	primary key(date, buy_date, number, package_id, sid, launch_date, course_id),
	constraint Redeem_buy_date_number_package_id foreign key(buy_date, number, package_id) references Buys(date, number, package_id),
	constraint Redeem_sid_launch_date_course_id foreign key(sid, launch_date, course_id) references Sessions_Conducts_Consists
);

-- checked
create table Specializes (
	eid int,
	name varchar(100),
	primary key(eid, name),
	constraint Specializes_eid foreign key(eid) references Instructors on delete cascade on update cascade,
	constraint Specializes_name foreign key(name) references Course_areas_Manages
);