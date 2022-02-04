FROM ubuntu:20.04

RUN apt -yqq update && apt -yqq install cmake gcc libssl-dev make sudo zlib1g-dev

WORKDIR /tmp
ADD pg.tar.gz .
RUN mv -v postgresql-* pg
WORKDIR /tmp/pg
RUN ./configure --prefix /usr --with-openssl --without-readline
RUN make -j $NPROC world
RUN make install-world
RUN rm -rf /tmp/pg

WORKDIR /tmp
ADD rum.tar.gz .
RUN mv -v rum-* rum
WORKDIR /tmp/rum
RUN make -j $NPROC USE_PGXS=1
RUN make install USE_PGXS=1
RUN rm -rf /tmp/rum

WORKDIR /tmp
ADD ts.tar.gz .
RUN mv -v timescaledb-* ts
WORKDIR /tmp/ts
RUN ./bootstrap -DREGRESS_CHECKS=OFF
WORKDIR /tmp/ts/build
RUN make -j $NPROC
RUN make install
RUN rm -rf /tmp/ts

ADD pg_hba.conf /pg_hba.conf
ADD postgresql.conf /postgresql.conf
RUN useradd --system --user-group --shell /sbin/nologin postgres
RUN mkdir /pgdata && chown postgres:postgres /pgdata

CMD sudo -u postgres initdb --pgdata=/pgdata --username=postgres && \
  cp /pg_hba.conf /pgdata/pg_hba.conf && \
  cp /postgresql.conf /pgdata/postgresql.conf && \
  sudo -u postgres pg_ctl -D /pgdata --log=/pgdata/server.log --wait start && \
  psql --no-readline --host 127.0.0.1 --user postgres --db postgres --command "CREATE USER "\""$POSTGRES_USER"\"" WITH SUPERUSER ENCRYPTED PASSWORD '$POSTGRES_PASSWORD'" && \
  psql --no-readline --host 127.0.0.1 --user postgres --db postgres --command "CREATE DATABASE "\""$POSTGRES_DB"\"" WITH OWNER = "\""$POSTGRES_USER"\""" && \
  tail -fn 1000 /pgdata/server.log