/* Copyright(C) 2011 Kentoku SHIBA

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef _mrn_table_h
#define _mrn_table_h

#if MYSQL_VERSION_ID >= 50500
#define my_free(A,B) my_free(A)
#endif

typedef struct st_mroonga_share
{
  char               *table_name;
  uint               table_name_length;
  uint               use_count;
  pthread_mutex_t    mutex;
  THR_LOCK           lock;
  TABLE_SHARE        *table_share;

  char               *engine;
  int                engine_length;
  plugin_ref         plugin;
  handlerton         *hton;
  bool               wrapper_mode;
} MRN_SHARE;

char *mrn_create_string(const char *str, uint length);
char *mrn_get_string_between_quote(char *ptr, bool alloc);
#ifdef WITH_PARTITION_STORAGE_ENGINE
void mrn_get_partition_info(const char *table_name, uint table_name_length,
                            const TABLE *table, partition_element **part_elem,
                            partition_element **sub_elem);
#endif
int mrn_parse_table_param(MRN_SHARE *share, TABLE *table);
MRN_SHARE *mrn_get_share(const char *table_name, TABLE *table, int *error);
int mrn_free_share(MRN_SHARE *share);
TABLE_SHARE *mrn_get_table_share(TABLE_LIST *table_list, int *error);
void mrn_free_table_share(TABLE_SHARE *share);

#endif /* _mrn_table_h */