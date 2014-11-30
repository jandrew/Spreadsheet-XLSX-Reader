#!/usr/bin/env perl
### Test that the module(s) load!(s)
use	Test::More;
BEGIN{ use_ok( Test::Pod, qw( 1.48 ) ) };
BEGIN{ use_ok( TAP::Formatter::Console ) };
BEGIN{ use_ok( TAP::Harness ) };
BEGIN{ use_ok( TAP::Parser::Aggregator ) };
BEGIN{ use_ok( version ) };
BEGIN{ use_ok( Test::Moose ) };
BEGIN{ use_ok( Data::Dumper ) };
BEGIN{ use_ok( Capture::Tiny, qw( capture_stderr ) ) };
BEGIN{ use_ok( Carp, qw( cluck ) ) };
BEGIN{ use_ok( XML::LibXML::Reader ) };
BEGIN{ use_ok( Type::Tiny, 0.046 ) };
BEGIN{ use_ok( Moose ) };
BEGIN{ use_ok( MooseX::StrictConstructor ) };
BEGIN{ use_ok( MooseX::HasDefaults::RO ) };
BEGIN{ use_ok( Archive::Zip ) };
BEGIN{ use_ok( OLE::Storage_Lite ) };
BEGIN{ use_ok( File::Temp ) };
BEGIN{ use_ok( DateTimeX::Format::Excel, 0.012 ) };
BEGIN{ use_ok( MooseX::ShortCut::BuildInstance, 1.026 ) };
BEGIN{ use_ok( MooseX::ShortCut::BuildInstance, qw( build_instance ) ) };
BEGIN{ use_ok( DateTime::Format::Flexible ) };
use	lib '../lib', 'lib';
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::Types, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::Error, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::LogSpace, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::XMLReader, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::XMLReader::XMLToPerlData, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::XMLReader::Worksheet, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::UtilFunctions, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::FmtDefault, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::XMLReader::SharedStrings, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::XMLReader::CalcChain, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::XMLReader::Styles, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::Cell, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML::GetCell, 0.018 ) };
BEGIN{ use_ok( Spreadsheet::XLSX::Reader::LibXML, 0.018 ) };
done_testing();