#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::components;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $pkg_restore = cpev->new->component('PackageRestore');

{
    note "Checking pre_leapp";

    my $stage_file_data;
    my @pkgs_to_check  = qw{ foo bar baz };
    my %installed_pkgs = (
        foo => 1,
        bar => 0,
        baz => 1,
    );

    my $mock_comp = Test::MockModule->new('Elevate::Components::PackageRestore');
    $mock_comp->redefine(
        _get_packages_to_check => sub { return @pkgs_to_check; },
    );

    my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_pkgr->redefine(
        is_installed => sub { return $installed_pkgs{ $_[0] }; },
    );

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        update_stage_file => sub { $stage_file_data = shift; },
    );

    $pkg_restore->pre_leapp();

    is(
        $stage_file_data,
        { packages_to_restore => [qw{ foo baz }] },
        'Correctly detects the installed packages and updates the stage file'
    );
}

{
    note "Checking post_leapp";

    my @mock_files;
    my @yum_installed;
    my %files_copied;
    my $stage_file_data = [qw{ foo bar baz }];
    my %restore_files   = (
        foo => [],
        bar => [qw{ myfile anotherfile yetanotherfile }],
        baz => [],
    );

    push @mock_files, Test::MockFile->file( 'myfile.rpmsave',      'contents' );
    push @mock_files, Test::MockFile->file( 'anotherfile.rpmsave', 'contents' );
    push @mock_files, Test::MockFile->file('yetanotherfile.rpmsave');

    my $mock_comp = Test::MockModule->new('Elevate::Components::PackageRestore');
    $mock_comp->redefine(
        _get_files_to_restore => sub { return $restore_files{ $_[0] }; },
    );

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        read_stage_file => sub { return $stage_file_data; },
    );

    my $mock_yum = Test::MockModule->new('Elevate::YUM');
    $mock_yum->redefine(
        install => sub { push @yum_installed, $_[1]; },
    );

    my $mock_copy = Test::MockModule->new('File::Copy');
    $mock_copy->redefine(
        copy => sub { $files_copied{ $_[0] } = $_[1] },
    );

    $pkg_restore->post_leapp();

    is(
        \@yum_installed,
        [qw{ foo bar baz }],
        'Attempted to install modules listed in the stage file'
    );

    is(
        \%files_copied,
        {
            'myfile.rpmsave'      => 'myfile',
            'anotherfile.rpmsave' => 'anotherfile',
        },
        'Attempted to copy the expected files'
    );
}

done_testing();
