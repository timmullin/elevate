#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib '/usr/local/cpanel/';

use Cpanel::OS ();

use Test::More;

is( Cpanel::OS->distro(), 'ubuntu', 'System is Ubuntu after upgrade.' );
is( Cpanel::OS->major(),  '22',     'Verson 22 of OS.' );

done_testing();
