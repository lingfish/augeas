(*
Module: Keepalived
  Parses /etc/keepalived/keepalived.conf

Author: Raphael Pinson <raphink@gmail.com>

About: Reference
  This lens tries to keep as close as possible to `man 5 keepalived.conf` where possible.

About: License
   This file is licenced under the LGPLv2+, like the rest of Augeas.

About: Lens Usage
   To be documented

About: Configuration files
   This lens applies to /etc/keepalived/keepalived.conf. See <filter>.
*)


module Keepalived =
  autoload xfm

(************************************************************************
 * Group:                 USEFUL PRIMITIVES
 *************************************************************************)

(* Group: Comments and empty lines *)

(* View: indent *)
let indent = Util.indent

(* View: eol *)
let eol = Util.eol

(* View: sep_spc *)
let sep_spc = del /[ \t]+/ " "

(* View: lbracket *)
let lbracket = Util.del_str "{"

(* View: rbracket *)
let rbracket = Util.del_str "}"

(* View: comment
Map comments in "#comment" nodes *)
let comment =
    [ indent . label "#comment" . del /[#!][ \t]*/ "# "
        . store /([^ \t\n].*[^ \t\n]|[^ \t\n])/ . eol ]

(* View: eol_comment
And end-of-line comment
with a space in front of # by default *)
let eol_comment =
    [ label "#comment" . del /[ \t]*[#!][ \t]*/ " # "
        . store /([^ \t\n].*[^ \t\n]|[^ \t\n])/ . eol ]

(* View: empty
Map empty lines *)
let empty   = Util.empty

(* View: sto_email_addr *)
let sto_email_addr = store /[A-Za-z0-9_\+\.-]+@[A-Za-z0-9_\.-]+/

(* Variable: word *)
let word = /[A-Za-z0-9_\.-]+/

(* Variable: word_slash *)
let word_slash = /[A-Za-z0-9_\.\/-]+/

(* View: sto_word *)
let sto_word = store word

(* View: sto_num *)
let sto_num = store /[0-9]+/

(* View: sto_to_eol
Should not be necessary once static_ipaddress_field uses fields *)
let sto_to_eol = store /[^}!# \t\n][^}!#\n]*[^}!# \t\n]|[^}!# \t\n]/


(* View: field *)
let field (kw:string) (sto:lens) = [ indent . key kw . sep_spc . sto . (eol_comment|eol) ]

(* View: flag
A single word *)
let flag (kw:regexp) = [ indent . key kw ]

(* View: lens_block
A generic block with a title lens *)
let lens_block (title:lens) (sto:lens) = [ indent . title . sep_spc . lbracket . eol
                                         . (sto | empty | comment)+
                                         . indent . rbracket . eol ]

(* View: block
A simple block with just a block title *)
let block (kw:string) (sto:lens) = lens_block (key kw) sto

(* View: named_block
A block with a block title and name *)
let named_block (kw:string) (sto:lens) = lens_block (key kw . sep_spc . sto_word) sto

(* View: named_block_arg_title
A title lens for named_block_arg *)
let named_block_arg_title (kw:string) (name:string) (arg:string) =
                            key kw . sep_spc
                          . [ label name . sto_word ]
                          . sep_spc
                          . [ label arg . sto_word ]

(* View: named_block_arg
A block with a block title, a name and an argument *)
let named_block_arg (kw:string) (name:string) (arg:string) (sto:lens) =
                           lens_block (named_block_arg_title kw name arg) sto


(************************************************************************
 * Group:                 GLOBAL CONFIGURATION
 *************************************************************************)

(* View: email
A simple email address entry *)
let email = [ indent . label "email" . sto_email_addr . (eol_comment|eol) ]

(* View: global_defs_field
Possible fields in the global_defs block *)
let global_defs_field = block "notification_email" email
                      | field "notification_email_from" sto_email_addr
                      | field "smtp_server" sto_word
                      | field "smtp_connect_timeout" sto_num
                      | field "lvs_id" sto_word
                      | field "router_id" sto_word

(* View: global_defs
A global_defs block *)
let global_defs = block "global_defs" global_defs_field

(* View: prefixlen
A prefix for IP addresses *)
let prefixlen = [ label "prefixlen" . Util.del_str "/" . sto_num ]

(* View: ipdev
A device for IP addresses *)
let ipdev = [ key "dev" . sep_spc . sto_word ]

(* View: static_ipaddress_field
The whole string is fed to ip addr add.
You can truncate the string anywhere you like and let ip addr add use defaults for the rest of the string.
To be refined with fields according to `ip addr help`.
*)
let static_ipaddress_field = [ indent . label "ipaddr"
                             . store /[0-9\.]+/
                             . prefixlen?
                             . (sep_spc . ipdev)?
                             . (eol|eol_comment) ]

(* View: static_routes_field
src $SRC_IP to $DST_IP dev $SRC_DEVICE
*)
let static_routes_field = [ indent . label "route"
                          . [ key "src" . sto_word ] . sep_spc
                          . [ key "to"  . sto_word ] . sep_spc
                          . [ key "dev" . sto_word ] . (eol|eol_comment) ]

(* View: static_routes *)
let static_routes = block "static_ipaddress" static_ipaddress_field
                  | block "static_routes" static_routes_field


(* View: global_conf
A global configuration entry *)
let global_conf = global_defs | static_routes


(************************************************************************
 * Group:                 VRRP CONFIGURATION
 *************************************************************************)

(*View: vrrp_sync_group_field *)
let vrrp_sync_group_field = block "group" [ indent . key word . (eol|eol_comment) ]

(* View: vrrp_sync_group *)
let vrrp_sync_group = named_block "vrrp_sync_group" vrrp_sync_group_field

(* View: vrrp_instance_field *)
let vrrp_instance_field = field "state" sto_word
                        | field "interface" sto_word
                        | field "lvs_sync_daemon_interface" sto_word
                        | field "virtual_router_id" sto_num
                        | field "priority" sto_num
                        | field "advert_int" sto_num
                        | flag "smtp_alert"
                        | flag "nopreempt"
                        | block "authentication" (
                                field "auth_type" sto_word
                              | field "auth_pass" sto_word
                              )
                        | block "virtual_ipaddress" static_ipaddress_field

(* View: vrrp_instance *)
let vrrp_instance = named_block "vrrp_instance" vrrp_instance_field


(* View: vrrpd_conf
contains subblocks of VRRP synchronization group(s) and VRRP instance(s) *)
let vrrpd_conf = vrrp_sync_group | vrrp_instance


(************************************************************************
 * Group:                 LVS CONFIGURATION
 *************************************************************************)

(* View: virtual_server_group *)

(* View: tcp_check_field *)
let tcp_check_field = field "connect_timeout" sto_num
                    | field "connect_port" sto_num

(* View: real_server_field *)
let real_server_field = field "weight" sto_num
                      | block "TCP_CHECK" tcp_check_field

(* View: virtual_server_field *)
let virtual_server_field = field "delay_loop" sto_num
                         | field "lb_algo" sto_word
                         | field "lb_kind" sto_word
                         | field "nat_mask" sto_word
                         | field "protocol" sto_word
                         | named_block_arg "real_server" "ip" "port" real_server_field

(* View: virtual_server *)
let virtual_server = named_block_arg "virtual_server" "ip" "port" virtual_server_field

(* View: lvs_conf
contains subblocks of Virtual server group(s) and Virtual server(s) *)
let lvs_conf = virtual_server


(* View: lns
     The keepalived lens
*)
let lns = ( empty | comment | global_conf | vrrpd_conf | lvs_conf )*

(* Variable: filter *)
let filter = incl "/etc/keepalived/keepalived.conf"
    . Util.stdexcl

let xfm = transform lns filter