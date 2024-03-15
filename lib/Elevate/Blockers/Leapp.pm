package Elevate::Blockers::Leapp;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Leapp

Blocker to check if leapp finds any upgrade inhibitors.

=cut

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    return if $self->is_check_mode();    # skip for --check

    return unless $self->should_run_leapp;    # skip when --no-leapp is provided

    return if ( $self->blockers->num_blockers_found() > 0 );    # skip if any blockers have already been found

    $self->cpev->leapp->install();

    my $out = $self->cpev->leapp->preupgrade();

    # A return code of zero indicates that no inhibitors
    # or fatal errors have been found.
    return if ( $out->{status} == 0 );

    # Leapp will generate a JSON report file which contains any
    # inhibitors found. Find any reported inhibitors but exclude ones
    # that we know about and will fix before the upgrade
    # (Inhibitors will also be reported in stdout in a block
    # labeled "UPGRADE INHIBITORS"; but more complete info is reported
    # in the JSON report file.)

    my $inhibitors = $self->cpev->leapp->search_report_file_for_inhibitors(
        qw(
          check_installed_devel_kernels
          cl_mysql_repository_setup
          verify_check_results
        )
    );

    foreach my $inhibitor (@$inhibitors) {
        my $message = $inhibitor->{title} . "\n";
        $message .= $inhibitor->{summary} . "\n";
        if ( $inhibitor->{hint} ) {
            $message .= "Possible resolution: " . $inhibitor->{hint} . "\n";
        }
        if ( $inhibitor->{command} ) {
            $message .= "Consider running:" . "\n" . $inhibitor->{command} . "\n";
        }

        $self->has_blocker($message);
    }

    # Fatal errors will NOT be flagged as inhibitors in the
    # leapp reports.  So it is possible to distinguish them from
    # any non-fatal conditions reported there.  So, we need to fish
    # them from stdout.

    my $error_block = _extract_error_block_from_output( $out->{stdout} );

    if ( length $error_block ) {
        $self->has_blocker( "Leapp encountered the following error(s):\n" . $error_block );
    }

    return;
}

sub _extract_error_block_from_output ($text_ar) {

    # The fatal errors will appear there in a block that looks like this:
    # =========================================
    #               ERRORS
    # =========================================
    #
    # Info about the errors
    #
    # =========================================
    #             END OF ERRORS
    # =========================================

    my $error_block = '';

    my $found_banner_line        = 0;
    my $found_second_banner_line = 0;
    my $in_error_block           = 0;

    foreach my $line (@$text_ar) {

        # Keep looking for a "banner" line (a line full of "=")
        if ( !$found_banner_line ) {
            $found_banner_line = 1 if $line =~ /^={10}/;
            next;
        }

        # We've found the banner line, check if this is the error block
        if ( !$in_error_block ) {
            if ( $line =~ /^\s+ERRORS/ ) {
                $in_error_block = 1;
            }
            else {
                # not the error block, go back to looking for a banner line
                $found_banner_line = 0;
            }
            next;
        }

        # We can't start harvesting the error info until we pass the second banner line
        if ( !$found_second_banner_line ) {
            $found_second_banner_line = 1 if $line =~ /^={10}/;
            next;
        }

        # If we come across another banner line, we are done with the error block
        last if $line =~ /^={10}/;

        $error_block .= $line;
    }

    return $error_block;
}

1;
