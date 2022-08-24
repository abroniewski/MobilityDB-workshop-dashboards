select
  name,
  setting,
  unit,
  short_desc
from pg_settings
where name in (
  'force_parallel_mode',
  'min_parallel_relation_size',
  'parallel_setup_cost',
  'parallel_tuble_cost',
  'max_parallel_workers_per_gather' )
  limit 10 ;

set max_parallel_workers_per_gather = 2;
set force_parallel_mode = "off";