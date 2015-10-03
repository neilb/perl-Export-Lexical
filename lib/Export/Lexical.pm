package Export::Lexical;

use 5.010;
use strict;
use version; our $VERSION = qv('0.0.4');

use B;
use Carp;

my %Exports_for  = ();
my %Modifier_for = ();  # e.g., $Modifier_for{$pkg} = 'silent'

sub MODIFY_CODE_ATTRIBUTES {
    my ( $package, $coderef, @attrs ) = @_;

    my @unused_attrs = ();

    while ( my $attr = shift @attrs ) {
        if ( $attr =~ /^Export_?Lexical$/i ) {
            push @{ $Exports_for{$package} }, $coderef;
        }
        else {
            push @unused_attrs, $attr;
        }
    }

    return @unused_attrs;
}

sub import {
    my ($class) = @_;

    my $caller = caller;
    my $key    = _get_key($caller);
    my @params = ();

    {
        # Export our subroutines, if necessary.
        no strict 'refs';   ## no critic (ProhibitNoStrict)

        if ( !exists &{ $caller . '::MODIFY_CODE_ATTRIBUTES' } ) {
            *{ $caller . '::MODIFY_CODE_ATTRIBUTES' } = \&MODIFY_CODE_ATTRIBUTES;
        }

        if ( !exists &{ $caller . '::import' } ) {
            *{ $caller . '::import' } = sub {
                my ( $class, @args ) = @_;

                _export_all_to( $caller, scalar caller );

                $^H{$key} = @args ? ( join ',', @args ) : 1;
            };
        }

        if ( !exists &{ $caller . '::unimport' } ) {
            *{ $caller . '::unimport' } = sub {
                my ( $class, @args ) = @_;

                if ( @args ) {
                    # Leave the '1' on the front of the list from a previous 'use
                    # $module', as well as any subs previously imported.
                    $^H{$key} = join ',', $^H{$key}, map { "!$_" } @args;
                }
                else {
                    $^H{$key} = '';
                }
            };
        }
    }

    while ( my $modifier = shift ) {
        if ( $modifier =~ /^:(silent|warn)$/ ) {
            croak qq('$modifier' requested when '$Modifier_for{$caller}' already in use)
                if $Modifier_for{$caller};

            $Modifier_for{$caller} = $modifier;
            next;
        }

        push @params, $modifier;
    }
}

sub _export_all_to {
    my ( $from, $caller ) = @_;

    return if !exists $Exports_for{$from};

    for my $ref ( @{ $Exports_for{$from} } ) {
        my $obj = B::svref_2object($ref);
        my $pkg = $obj->GV->STASH->NAME;
        my $sub = $obj->GV->NAME;
        my $key = _get_key($pkg);

        no strict 'refs';       ## no critic (ProhibitNoStrict)
        no warnings 'redefine';

        next if exists &{ $caller . '::' . $sub };

        *{ $caller . '::' . $sub } = sub {
            my $hints = (caller(0))[10];

            return _fail( $pkg, $sub ) if $hints->{$key} =~ /(?:^$)|(?:!$sub\b)/; # no $module
                                                                                  # no $module '$sub'

            goto $ref if $hints->{$key} =~ /(?:^1\b)|(?:\b$sub\b)/;               # use $module
                                                                                  # use $module '$sub'
        };
    }
}

sub _fail {
    my ( $pkg, $sub ) = @_;

    if ( $Modifier_for{$pkg} eq ':silent' ) {
        return;
    }

    if ( $Modifier_for{$pkg} eq ':warn' ) {
        carp "$pkg\::$sub not allowed here";
        return;
    }

    croak "$pkg\::$sub not allowed here";
}

sub _get_key {
    my ($pkg) = @_;

    return __PACKAGE__ . '/' . $pkg;
}

1;

__END__

=head1 NAME

Export::Lexical - Lexically scoped subroutine imports

=head1 VERSION

This document describes Export::Lexical version 0.0.4

=head1 SYNOPSIS

    package Foo;

    use Export::Lexical;

    sub foo :ExportLexical {
        # do something
    }

    sub bar :ExportLexical {
        # do something else
    }

    # In a nearby piece of code...

    use Foo;

    foo();    # calls foo()
    bar();    # calls bar()

    {
        no Foo 'bar';    # disables bar()

        foo();           # calls foo()
        bar();           # throws an exception
    }

=head1 DESCRIPTION

The Export::Lexical module provides a simple interface to the custom user
pragma interface in Perl 5.10.  Simply by marking subroutines of a module with
the C<:ExportLexical> attribute, they will automatically be flagged for
lexically scoped import.

=head1 INTERFACE 

=head2 Import Modifiers

By default, subroutines not currently exported to the lexical scope will raise
exceptions when called.  This behavior can be modified in two ways.

=over

=item C<< :silent >>

    use Export::Lexical ':silent';

Causes subroutines not imported into the current lexical scope to be no-ops.

=item C<< :warn >>

    use Export::Lexical ':warn';

Causes subroutines not imported into the current lexical scope to warn with
carp() instead of dying with croak().

=back

=head2 Subroutine Attributes

=over

=item C<< :ExportLexical >>

    package Foo;

    sub foo :ExportLexical {
        # do something
    }

This marks the foo() subroutine for lexically scoped import.  When the Foo
module in this example is used, the foo() subroutine is available only in the
scope of the C<use> statement.  The foo() subroutine can be made into a no-op
with the C<no> statement.

=back

=head1 DIAGNOSTICS

No diagnostics exist in this version of Export::Lexical.

=head1 CONFIGURATION AND ENVIRONMENT

Export::Lexical requires no configuration files or environment variables.

=head1 DEPENDENCIES

=over

=item *

Perl v5.10.0+

=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

Do not define C<import()> or C<unimport()> subroutines when using
Export::Lexical.  These will redefine the subroutines created by the
Export::Lexical module, disabling the special properties of the attributes.
In practice, this probably isn't a big deal.

Please report any bugs or feature requests to
C<bug-export-lexical@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Chris Grau C<< <cgrau@cpan.org> >>

This module is an expansion of an idea presented by Damian Conway.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008 - 2010, Chris Grau C<< <cgrau@cpan.org> >>.  All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.  See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE
SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE
STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE
SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND
PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE,
YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY
COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE
SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING BUT NOT LIMITED TO
LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR
THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER
SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES.

=head1 SEE ALSO

L<perlpragma>

=cut
