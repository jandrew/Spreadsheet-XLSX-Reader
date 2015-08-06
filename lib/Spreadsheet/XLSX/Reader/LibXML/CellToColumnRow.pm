package Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow;
use version; our $VERSION = qv('v0.38.9');
###LogSD	warn "You uncovered internal logging statements for Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow-$VERSION";

use	Moose::Role;
requires
			'set_error',
###LogSD	'get_log_space',
;
use Types::Standard qw( Bool );
###LogSD	use Log::Shiras::Telephone;

#########1 Dispatch Tables    3#########4#########5#########6#########7#########8#########9

my	$lookup_ref ={
		A => 1, B => 2, C => 3, D => 4, E => 5, F => 6, G => 7, H => 8, I => 9, J => 10,
		K => 11, L => 12, M => 13, N => 14, O => 15, P => 16, Q => 17, R => 18, S => 19,
		T => 20, U => 21, V => 22, W => 23, X => 24, Y => 25, Z => 26,
	};
my	$lookup_list =[ qw( A B C D E F G H I J K L M N O P Q R S T U V W X Y Z ) ];

#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9



#########1 Public Methods     3#########4#########5#########6#########7#########8#########9

sub parse_column_row{
	my ( $self, $cell ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space =>
	###LogSD					($self->get_log_space .  '::parse_column_row' ), );
	###LogSD		$phone->talk( level => 'debug', message =>[
	###LogSD			"Parsing file row number and file column number from: $cell" ] );
	my ( $column, $row ) = $self->_parse_column_row( $cell );
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		'File Column: ' . ($column//''), 'File Row: ' . ($row//'') ] );
	###LogSD	use warnings 'uninitialized';
	return( $column, $row );
}

sub build_cell_label{
	my ( $self, $column, $row ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space =>
	###LogSD					($self->get_log_space .  '::build_cell_label' ), );
	###LogSD		$phone->talk( level => 'debug', message =>[
	###LogSD			"Converting file column -$column- and file row -$row- to a cell ID" ] );
	my $cell_label = $self->_build_cell_label( $column, $row );
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		"Cell label is: $cell_label" ] );
	return $cell_label;
}

#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9



#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub _parse_column_row{
	my ( $self, $cell ) = @_;
	my ( $column, $error_list_ref );
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space =>
	###LogSD					($self->get_log_space .  '::_parse_column_row' ), );
	###LogSD		$phone->talk( level => 'debug', message =>[
	###LogSD			"Parsing excel row and column number from: $cell" ] );
	my	$regex = qr/^([A-Z])?([A-Z])?([A-Z])?([0-9]*)$/;
	my ( $one_column, $two_column, $three_column, $row ) = $cell =~ $regex;
	no	warnings 'uninitialized';
	my	$column_text = $one_column . $two_column . $three_column;
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		"Regex result is: ( $one_column, $two_column, $three_column, $row )" ] );
	
	if( !defined $one_column ){
		push @$error_list_ref, "Could not parse the column component from -$cell-";
	}elsif( !defined $two_column ){
		$column = $lookup_ref->{$one_column};
	}elsif( !defined $three_column ){
		$column = $lookup_ref->{$two_column} + 26 * $lookup_ref->{$one_column};
	}else{
		$column = $lookup_ref->{$three_column} + 26 * $lookup_ref->{$two_column} + 26 * 26 * $lookup_ref->{$one_column};
	}
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		"Result of initial parse is column text: $column_text",
	###LogSD		"Column number: $column", "Row number: $row" ] );
	if( $column_text and $column > 16384 ){
		push @$error_list_ref, "The column text -$column_text- points to a position at " .
									"-$column- past the excel limit of: 16,384";
		$column = undef;
	}
	if( !defined $row or $row eq '' ){
		push @$error_list_ref, "Could not parse the row component from -$cell-";
		$row = undef;
	}elsif( $row < 1 ){
		push @$error_list_ref, "The requested row cannot be less than one - you requested: $row";
		$row = undef;
	}elsif( $row > 1048576 ){
		push @$error_list_ref, "The requested row cannot be greater than 1,048,576 " .
									"- you requested: $row";
		$row = undef;
	}
	if( $error_list_ref ){
		if( scalar( @$error_list_ref ) > 1 ){
			$self->set_error( "The regex $regex could not match -$cell-" );
		}else{
			$self->set_error( $error_list_ref->[0] );
		}
	}
	###LogSD	no warnings 'uninitialized';
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		"Column: $column", "Row: $row" ] );
	use warnings 'uninitialized';
	return( $column, $row );
}

sub _build_cell_label{
	my ( $self, $column, $row ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space =>
	###LogSD					($self->get_log_space .  '::build_cell_label' ), );
	###LogSD	no	warnings 'uninitialized';
	###LogSD		$phone->talk( level => 'debug', message =>[
	###LogSD			"Converting column -$column- and row -$row- to a cell ID" ] );
	###LogSD	use	warnings 'uninitialized';
	my $error_list;
	if( !defined $column ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"The column is not defined" ] );
		$column = '';
		push @$error_list, 'missing column';
	}else{
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Excel column: $column" ] );
		$column -= 1;
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"From zero: $column" ] );
		if( $column > 16383 ){
			push @$error_list, 'column too large';
			$column = '';
		}elsif( $column < 0 ){
			push @$error_list, 'column too small';
			$column = '';
		}else{
			my $first_letter = int( $column / (26 * 26) );
			$column = $column - $first_letter * (26 * 26);
			$first_letter = ( $first_letter ) ? $lookup_list->[$first_letter - 1] : '';
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		"First letter is: $first_letter", "New column is: $column" ] );
			my $second_letter = int( $column / 26 );
			$column = $column - $second_letter * 26;
			$second_letter =
				( $second_letter ) ? $lookup_list->[$second_letter - 1] : 
				( $first_letter ne '' ) ? 'A' : '' ;
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		"Second letter is: $second_letter", "New column is: $column" ] );
			my $third_letter = $lookup_list->[$column];
			$column = $first_letter . $second_letter . $third_letter;
		}
	}
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		"Column letters are: $column" ] );
	
	if( !defined $row ){
		$row = '';
		push @$error_list, 'missing row';
	}else{
		if( $row > 1048576 ){
			push @$error_list, 'row too large';
			$row = '';
		}elsif( $row < 1 ){
			push @$error_list, 'row too small';
			$row = '';
		}
	}
	$self->set_error(
		"Failures in build_cell_label include: " . join( ' - ', @$error_list )
	) if $error_list;
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		"Row is: $row" ] );
	
	my $cell_label = "$column$row";
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		"Cell label is: $cell_label" ] );
	return $cell_label;
}

#########1 Phinish            3#########4#########5#########6#########7#########8#########9

no Moose::Role;
1;

#########1 Documentation      3#########4#########5#########6#########7#########8#########9
__END__

=head1 NAME

Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow - Translate Excel cell IDs to column row

=head1 SYNOPSIS
	
	#!/usr/bin/env perl
	package MyPackage;
	use Moose;
	with 'Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow';

	sub set_error{} #Required method of this role
	sub error{ print "Missing the column or row\n" }
		
	sub my_method{
		my ( $self, $cell ) = @_;
		my ($column, $row ) = $self->parse_column_row( $cell );
		print $self->error if( !defined $column or !defined $row );
		return ($column, $row );
	}

	package main;

	my $parser = MyPackage->new;
	print '(' . join( ', ', $parser->my_method( 'B2' ) ) . ")'\n";
	
	###########################
	# SYNOPSIS Screen Output
	# 01: (2, 2)
	###########################
    
=head1 DESCRIPTION

This documentation is written to explain ways to use this module when writing your 
own excel parser.  To use the general package for excel parsing out of the box please 
review the documentation for L<Workbooks|Spreadsheet::XLSX::Reader::LibXML>,
L<Worksheets|Spreadsheet::XLSX::Reader::LibXML::Worksheet>, and 
L<Cells|Spreadsheet::XLSX::Reader::LibXML::Cell>

This is a L<Moose Role|Moose::Manual::Roles>. The role provides methods to convert back 
and forth betwee Excel Cell ID and ($column $row) lists.  This role also provides a layer 
of abstraction so that it is possible to implement 
L<around|Moose::Manual::MethodModifiers/Around modifiers> mofifiers on these methods so 
that the data provided by the user can be in the user context and the method implementation 
will still be in the Excel context.  For example this package uses this abstraction to allow 
the user to call or receive row column numbers in either the 
L<count-from-zero|Spreadsheet::XLSX::Reader::LibXML/count_from_zero> context used by 
L<Spreadsheet::ParseExcel> or the count-from-one context used by Excel.  It is important 
to note that column letters do not equal digits in a modern 26 position numeral system 
since the excel implementation is effectivly zeroless.

The module counts from 1 (the excel convention) without implementation of around modifiers.  
Meaning that cell ID 'A1' is equal to (1, 1) and column row (3, 2) is equal to the cell ID 
'C2'.

=head2 requires

These are methods used by this role but not provided by the role.  Any class consuming this 
role will not build unless it first provides these methods prior to loading this role.

=head3 set_error( $error_string )

=over

B<Definition:> Used to set errors that occur in code from this role.  See
L<Spreadsheet::XLSX::Reader::LibXML::Error> for the default implementation of this functionality.

=back
	
=head2 Methods

Methods are object methods (not functional methods)

=head3 parse_column_row( $excel_cell_id )

=over

B<Definition:> This is the way to turn an alpha numeric Excel cell ID into column and row 
integers.  This method uses a count from 1 methodology.  Since this method is actually just 
a layer of abstraction above the real method for the calculation you can wrap it in an 
L<around|Moose::Manual::MethodModifiers/Around modifiers> block to modify the output to 
the desired user format without affecting other parts of the package that need the 
unfiltered conversion.  If you want both then use the following call when unfiltered results 
are required;

	$self->_parse_column_row( $excel_cell_id )

B<Accepts:> $excel_cell_id

B<Returns:> ( $column_number, $row_number )

=back

=head3 build_cell_label( $column, $row, )

=over

B<Definition:> This is the way to turn a (column, row) pair into an Excel Cell ID.  The  
underlying method uses a count from 1 methodology.  Since this method is actually just 
a layer of abstraction above the real method for the calculation you can wrap it in an 
L<around|Moose::Manual::MethodModifiers/Around modifiers> block to modify the input from 
the implemented user format to the count from one methodology without affecting other parts 
of the package that need the unfiltered conversion.  If you want both then use the following 
call when unfiltered results are required;

	$self->_build_cell_label( $column, $row )
	
The column and the row must be provided in that order for both public and private methods.

B<Accepts:> ($column, $row) I<in that order>

B<Returns:> ( $excel_cell_id ) I<qr/[A-Z]{1,3}\d+/>

=back

=head1 SUPPORT

=over

L<github Spreadsheet::XLSX::Reader::LibXML/issues
|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML/issues>

=back

=head1 TODO

=over

B<1.> Nothing L<yet|/SUPPORT>

=back

=head1 AUTHOR

=over

Jed Lund

jandrew@cpan.org

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

This software is copyrighted (c) 2014, 2015 by Jed Lund

=head1 DEPENDENCIES

=over

L<version> - 0.77

L<Moose::Role>

L<Types::Standard>

=back

=head1 SEE ALSO

=over

L<Spreadsheet::ParseExcel> - Excel 2003 and earlier

L<Spreadsheet::XLSX> - 2007+

L<Spreadsheet::ParseXLSX> - 2007+

L<Log::Shiras|https://github.com/jandrew/Log-Shiras>

=over

All lines in this package that use Log::Shiras are commented out

=back

=back

=cut

#########1#########2 main pod documentation end  5#########6#########7#########8#########9