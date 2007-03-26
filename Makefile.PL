# -*- Perl -*-
#
# File:  Makefile.PL
# Desc:  Make the makefile for the PTools-SDF-DB distribution
# Date:  Sat Mar 24 20:59:01 2007
#
use inc::Module::Install;

name		'PTools-SDF-DB';
author		'Chris Cobb <nospamplease@ccobb.net>';
license 	'perl';
abstract	'Simple Data File DBMS w/schema, dbutil, and remote access';
perl_version	'5.006';
version		'0.01';
##all_from	'lib/PTools/SDF/DB.pm';

tests		't/*.t';   ##  t/*/*.t t/*/*/*.t';

# When building this distribution
#no_index	directory 	=> 'eg';
build_requires	Test::More	=> 0;

# Standard modules needed
requires	strict		=> 0;
requires	warnings	=> 0;

# Additional resources needed
requires	Getopt::Long		=> 2.17;
requires	Net::Server		=> 0;
requires	PTools::Local		=> 0;
requires	PTools::SDF::SDF	=> 0;
requires	RPC::PlClient		=> 0;
requires	RPC::PlServer		=> 0;
requires	Storable		=> 0;

WriteAll();
