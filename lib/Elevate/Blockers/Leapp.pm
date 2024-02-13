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

    $self->cpev->leapp->install(0);

    $self->cpev->leapp->preupgrade();

    my $blockers = $self->cpev->leapp->search_report_file_for_blockers();

    foreach my $blocker (@$blockers) {
        my $message = $blocker->{title} . "\n";
        $message .= $blocker->{summary} . "\n";
        if ( $blocker->{hint} ) {
            $message .= "Possible resolution: " . $blocker->{hint} . "\n";
        }
        if ( $blocker->{command} ) {
            $message .= "Consider running:" . "\n" . $blocker->{command} . "\n";
        }

        $self->has_blocker($message);
    }

    return;
}

1;
