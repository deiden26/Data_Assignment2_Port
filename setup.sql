create table port_users (
	email varchar(35) primary key,
	password varchar(35) not null
);

create table port_portfolio (
	name varchar(35) not null,
	email varchar(35) not null references port_users(email),
	cash number not null, check (cash>=0)
);

alter table port_portfolio add constraint pk_port_portfolio primary key (name, email);

create table port_stocksDaily as select * from cs339.StocksDaily;

alter table port_stocksDaily add constraint pk_port_stocksDaily primary key (symbol, timestamp);

create table port_stocksUser (
	symbol varchar(16) not null references port_stocksDaily(symbol),
	amount number not null, check (amount>=0),
	name varchar(35) not null,
	email varchar(35) not null references port_users(email)
);

alter table port_stocksUser add constraint pk_port_stocksUser primary key (symbol, name, email);

create table port_betaCach (symbol varchar(16) primary key, beta number not null, entries number not null);