create table port_user (
	email varchar(35) primary key,
	password varchar(35) not null
);

create table port_portfolio (
	name varchar(35) not null,
	email varchar(35) not null references port_users(email),
	cash number not null, check (cash>=0)
);

alter table port_portfolio add constraint pk_port_portfolio PRIMARY KEY(name, email);