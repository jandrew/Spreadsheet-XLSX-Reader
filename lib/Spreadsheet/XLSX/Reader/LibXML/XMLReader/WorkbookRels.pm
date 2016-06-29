package Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorkbookRels;
use version; our $VERSION = version->declare('v0.44.6');
###LogSD	warn "You uncovered internal logging statements for Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorkbookRels-$VERSION";

use	Moose::Role;
requires qw(
	location_status			advance_element_position		parse_element
	_get_rel_info			_get_sheet_info					get_sheet_names
	_get_workbook_file_type
);
###LogSD	requires 'get_log_space', 'get_all_space';
use Types::Standard qw( Enum ArrayRef HashRef Bool );
use Data::Dumper;
use lib	'../../../../../lib',;
###LogSD	use Log::Shiras::Telephone;

#########1 Dispatch Tables    3#########4#########5#########6#########7#########8#########9



#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9



#########1 Public Methods     3#########4#########5#########6#########7#########8#########9



#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has _loaded =>(
		isa			=> Bool,
		writer		=> '_good_load',
		reader		=> 'loaded_correctly',
		default		=> 0,
	);

has _sheet_lookup =>(
		isa		=> HashRef,
		traits	=> ['Hash'],
		reader	=> '_get_sheet_lookup',
		handles	=>{
			_set_sheet_info => 'set',
		},
		default	=> sub{ {} },
	);

has _worksheet_list =>(
		isa		=> ArrayRef,
		traits	=> ['Array'],
		reader	=> '_get_worksheet_list',
		handles	=>{
			_add_worksheet	=> 'push',
		},
		default	=> sub{ [] },
	);

has _chartsheet_list =>(
		isa		=> ArrayRef,
		traits	=> ['Array'],
		reader	=> '_get_chartsheet_list',
		handles	=>{
			_add_chartsheet  => 'push',
		},
		default	=> sub{ [] },
	);

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub _load_unique_bits{
	my( $self, ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space =>
	###LogSD			$self->get_all_space . '::_load_unique_bits', );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Setting the WorkbookRelsInterface unique bits" ] );
	
	# Build the list
	#~ $self->start_the_file_over;
	my ( $worksheet_list, $chartsheet_list );
	my $sheet_name_list = $self->get_sheet_names;
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Working on the sheet name list:", $sheet_name_list ] );
	for my $sheet ( @$sheet_name_list ){
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD		"Categorizing sheet: $sheet" ] );
		my	$sheet_ref = $self->_get_sheet_info( $sheet );
		$self->_set_sheet_info( $sheet => $sheet_ref );# No update needed for XML flat files - pass through
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD		"parsing out worksheet or chartsheet from:", $sheet_ref ] );
		if( $sheet_ref->{sheet_type} ){
			if( $sheet_ref->{sheet_type} eq 'worksheet' ){
				push @$worksheet_list, $sheet;
			}elsif( $sheet_ref->{sheet_type} eq 'chartsheet' ){
				push @$chartsheet_list, $sheet;
			}else{
				confess "Unrecognized sheet type: $sheet_ref->{sheet_type}";
			}
		}else{
			confess "Found a sheet without a sheet type:" . Dumper( $sheet_ref );
		}
	}
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Loading the worksheet list with:", $worksheet_list ] );
	map{ $self->_add_worksheet( $_ ) if $_ } @$worksheet_list if $worksheet_list;
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Loading the chartsheet list with:", $chartsheet_list ] );
	map{ $self->_add_chartsheet( $_ ) if $_ } @$chartsheet_list if $chartsheet_list;
	
	###LogSD	$phone->talk( level => 'trace', message => [
	###LogSD		"Closing out the xml file" ] );
	$self->_close_file_and_reader;
	$self->_good_load( 1 );
}

#########1 Phinish            3#########4#########5#########6#########7#########8#########9

no Moose::Role;
1;

#########1 Documentation      3#########4#########5#########6#########7#########8#########9
__END__

=head1 NAME

Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorkbookRels -  XML file Workbook Rels unique reader

=head1 SYNOPSIS


    
=head1 DESCRIPTION

 NOT WRITTEN YET!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

=head1 SUPPORT

=over

L<github Spreadsheet::XLSX::Reader::LibXML/issues
|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML/issues>

B<1.> Add the workbook attributute to the documentation

=back

=head1 TODO

=over

Nothing Yet 

=back

=head1 AUTHOR

=over

=item Jed Lund

=item jandrew@cpan.org

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

L<perl 5.010|perl/5.10.0>

L<Moose>

L<MooseX::StrictConstructor>

L<MooseX::HasDefaults::RO>

L<Carp> - confess

L<Type::Tiny> - 1.000

L<Clone> - clone

L<MooseX::ShortCut::BuildInstance> - build_instance should_re_use_classes

L<Spreadsheet::XLSX::Reader::LibXML> - which has it's own dependancies

L<Spreadsheet::XLSX::Reader::LibXML::XMLReader>

L<Spreadsheet::XLSX::Reader::LibXML::WorksheetToRow>

L<Spreadsheet::XLSX::Reader::LibXML::Row>

L<Spreadsheet::XLSX::Reader::LibXML::Cell>

L<Spreadsheet::XLSX::Reader::LibXML::Types>

L<Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow>

L<Spreadsheet::XLSX::Reader::LibXML::XMLToPerlData>

L<Moose::Role>

=over

B<requires>

any re-use of this role (Interface) requires the following methods. Links are provided 
to the existing package implementation for study.

=over

L<_min_row|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_min_row>

L<_max_row|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_max_row>

L<_min_col|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_min_col>

L<_max_col|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_max_col>

L<_get_col_row|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_get_col_row>

L<_get_next_value_cell|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_get_next_value_cell>

L<_get_row_all|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_get_row_all>

L<_get_merge_map|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_get_merge_map>

L<is_sheet_hidden|Spreadsheet::XLSX::Reader::LibXML::XMLReader::WorksheetToRow/_get_merge_map>

=back

=back

=back

=head1 SEE ALSO

=over

L<Spreadsheet::ParseExcel> - Excel 2003 and earlier

L<Spreadsheet::ParseXLSX> - 2007+

L<Spreadsheet::Read> - Generic

L<Spreadsheet::XLSX> - 2007+

L<Log::Shiras|https://github.com/jandrew/Log-Shiras>

=over

All lines in this package that use Log::Shiras are commented out

=back

=back

=cut

#########1#########2 main pod documentation end  5#########6#########7#########8#########9