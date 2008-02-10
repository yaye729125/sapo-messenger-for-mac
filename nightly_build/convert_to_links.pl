#!/usr/bin/perl -w
#
# Convert patterns of ticket and revision references to links
#

use strict;

my $trac_base_url = 'http://trac.softwarelivre.sapo.pt/sapo_msg_mac';

while (my $l = <>) {
  # Match Rev. ID: and switch to changeset link
  $l =~ s{
    Rev[.]\s+
    (\d+)
    :
  }
  {Rev. <a href="$trac_base_url/changeset/$1">$1</a>:}gx;
  
  # Match #TICKET and switch to ticket link
  $l =~ s{
    (
      \#
      (\d+)
    )
  }{<a href="$trac_base_url/ticket/$2">$1</a>}gx;
  
  print $l;
}
