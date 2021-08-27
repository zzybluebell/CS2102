drop table Scores;

create table Scores(
	Name text primary key,
	Mark int
);


create or replace function for_elise_func() 
returns trigger as $$
	begin
		if (old.Name ='Ee') Then 
			old.Mark := 1;
		end if;
		return old;
	end;
$$ language plpgsql;

create trigger for_elise_trigger 
before insert on Scores
for each row execute function for_elise_func();

insert into Scores values('Elise', 1);
select * from Scores;


