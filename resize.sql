REM Script is meant for Oracle version 9 and higher
REM -----------------------------------------------

set serveroutput on
exec dbms_output.enable(1000000);

declare

cursor c_dbfile is
select f.tablespace_name,f.file_name,f.file_id,f.blocks,t.block_size
from dba_data_files f,
dba_tablespaces t
where f.tablespace_name = t.tablespace_name
and t.status = 'ONLINE'
order by f.tablespace_name,f.file_id;

cursor c_freespace(v_file_id in number) is
select block_id, block_id+blocks max_block
from dba_free_space
where file_id = v_file_id
order by block_id desc;

/* variables to check settings/values */
dummy number;
checkval varchar2(10);
block_correction number;

/* running variable to show (possible) end-of-file */
file_min_block number;

/* variables to check if recycle_bin is on and if extent as checked is in ... */
recycle_bin boolean:=false;
extent_in_recycle_bin boolean;

/* exception handler needed for non-existing tables note:344940.1 */
sqlstr varchar2(100);
table_does_not_exist exception;
pragma exception_init(table_does_not_exist,-942);

begin

/* recyclebin is present in Oracle 10.2 and higher and might contain extent as checked */
begin
select value into checkval from v$parameter where name = 'recyclebin';
if checkval = 'on'
then
recycle_bin := true;
end if;
exception
when no_data_found
then
recycle_bin := false;
end;

/* main loop */
for c_file in c_dbfile
loop
/* initialization of loop variables */
dummy :=0;
extent_in_recycle_bin := false;
file_min_block := c_file.blocks;

begin


<<check_free>>

for c_free in c_freespace(c_file.file_id)
loop
/* if blocks is an uneven value there is a need to correct with -1 to compare with end-of-file which is even */
block_correction := (0-mod(c_free.max_block,2));
if file_min_block = c_free.max_block+block_correction
then

/* free extent is at end so file can be resized */
file_min_block := c_free.block_id;

else
/* no more free extent at end of file, file cannot be further resized */
exit check_free;
end if;
end loop;
end;

/* check if file can be resized, minimal size of file 16 blocks */
if (file_min_block = c_file.blocks) or (c_file.blocks <= 16)
then

dbms_output.put_line('Tablespace: '||c_file.tablespace_name||' Datafile: '||c_file.file_name);
dbms_output.put_line('cannot be resized no free extents found');
dbms_output.put_line('.');

else

/* file needs minimal no of blocks which does vary over versions */
if file_min_block < 16
then
file_min_block := 16;
end if;

dbms_output.put_line('Tablespace: '||c_file.tablespace_name||' Datafile: '||c_file.file_name);
dbms_output.put_line('current size: '||(c_file.blocks*c_file.block_size)/1024||'K'||' can be resized to: '||round((file_min_block*c_file.block_size)/1024)||'K (reduction of: '||round(((c_file.blocks-file_min_block)/c_file.blocks)*100,2)||' %)');

/* below is only true if recyclebin is on */
if recycle_bin
then
begin
sqlstr:='select distinct 1 from recyclebin$ where file#='||c_file.file_id;
execute immediate sqlstr into dummy;

if dummy > 0
then

dbms_output.put_line('Extents found in recyclebin for above file/tablespace');
dbms_output.put_line('Implying that purge of recyclebin might be needed in order to resize');
dbms_output.put_line('SQL> purge tablespace '||c_file.tablespace_name||';');
end if;
exception
when no_data_found
then null;
when table_does_not_exist
then null;
end;
end if;

Begin
execute immediate 'alter database datafile '''||c_file.file_name||''' resize '||round((file_min_block*c_file.block_size)/1024)||'K'  ;
dbms_output.put_line('Success - alter database datafile '''||c_file.file_name||''' resize '||round((file_min_block*c_file.block_size)/1024)||'K;');
exception
 when others then
  dbms_output.put_line('Failed - alter database datafile '''||c_file.file_name||''' resize '||round((file_min_block*c_file.block_size)/1024)||'K;');

end ;  
end if;

end loop;

end;
/



