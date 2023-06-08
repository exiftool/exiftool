#------------------------------------------------------------------------------
# File:         7Z.pm
#
# Description:  Read 7z archive meta information
#
# Revisions:    2023/04/28 - Amir Gooran (Cyberno)
#               2023-05-06 - PH Minor changes in ExifTool interfacing
#
# References:   1) https://py7zr.readthedocs.io/en/latest/archive_format.html
#------------------------------------------------------------------------------

package Image::ExifTool::7Z;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ReadUInt32 {
    my $buff;

    $_[0]->Read($buff, 4);
    my ($output) = unpack('L', $buff);
    return $output;
}

sub ReadUInt64 {
    my $buff;
    my $output;

    $_[0]->Read($buff, 1);
    my $b = ord($buff);
    if($b == 255){  # read real uint64
        $_[0]->Read($buff, 8);
        my ($output) = unpack('Q', $buff);
        return $output;
    }
    my @blen = (0x7F, 0xBF, 0xDF, 0xEF, 0xF7, 0xFB, 0xFD, 0xFE);

    my $mask = 0x80;
    my $vlen = 8;

    for (my $l = 0 ; $l < scalar(@blen) ; $l++) {
        my $v = $blen[$l];
        if($b <= $v){
            $vlen = $l;
            last;
        }
        $mask >>= 1;
    }
    if($vlen == 0){
        return $b & ($mask - 1);
    }
    $_[0]->Read($buff, $vlen);
    $buff .= "\0\0\0\0\0\0\0\0";

    my $value = unpack('Q', $buff);
    my $highpart = $b & ($mask - 1);
    return $value + ($highpart << ($vlen * 8));
}

sub ReadRealUInt64 {
    my $buff;

    $_[0]->Read($buff, 8);
    my $value = unpack('Q', $buff);
    return $value;
}

sub ReadBoolean {
    my $buff;
    my $count = $_[1];
    my $checkall = $_[2];
    my @result = ();

    if($checkall){
        $_[0]->Read($buff, 1);
        my $all_defined = ord($buff);
        if($all_defined != 0){
            @result = (1)x$count;
            return @result;
        }
    }

    my $b = 0;
    my $mask = 0;

    for (my $i = 0 ; $i < $count ; $i++) {
        if($mask == 0){
            $_[0]->Read($buff, 1);
            $b = ord($buff);
            $mask = 0x80;
        }
        push(@result, ($b & $mask) != 0);
        $mask >>= 1;
    }
    return @result;
}

sub ReadUTF16 {
    my $val = "";
    my $ch;

    for(my $i=0; $i < 65536; $i++){
        $_[0]->Read($ch, 2);
        if($ch eq "\0\0"){
            last;
        }
        $val .= $ch;
    }
    return $val;
}

sub ReadPackInfo {
    my $et = shift;

    my $buff;
    my %out_packinfo = ();
    $out_packinfo{"packsizes"} = ();

    $out_packinfo{"packpos"} = ReadUInt64($_[0]);
    my $numstreams = ReadUInt64($_[0]);
    $et->VPrint(0, "Number Of Streams: $numstreams\n");

    $_[0]->Read($buff, 1);
    my $pid = ord($buff);

    my @packsizes;
    if($pid == 9){  # size
        for (my $i = 0 ; $i < $numstreams ; $i++) {
            push(@{ $out_packinfo{"packsizes"} }, ReadUInt64($_[0]));
        }
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
        if($pid == 10){  # crc
            my @crcs;
            my @digestdefined = ReadBoolean($_[0], $numstreams, 1);
            foreach my $crcexist (@digestdefined) {
                if($crcexist){
                    push(@crcs, ReadUInt32($_[0]));
                }
            }
            $_[0]->Read($buff, 1);
            $pid = ord($buff);
        }
    }
    if($pid != 0) {  # end id expected
        return 0;
    }
    return \%out_packinfo;
}

sub findInBinPair {
    my @bindpairs = @{$_[0]};
    my $index = $_[1];

    for (my $i = 0; $i < scalar(@bindpairs); $i++) {
        if($bindpairs[$i] == $index){
            return $i;
        }
    }
    return -1;
}

sub ReadFolder {
    my $et = shift;
    my $buff;
    my $totalin = 0;
    my $totalout = 0;
    my %out_folder = ();
    $out_folder{"packed_indices"} = ();
    $out_folder{"bindpairs"} = ();
    $out_folder{"coders"} = ();

    my $num_coders = ReadUInt64($_[0]);
    $et->VPrint(0, "Number of coders: $num_coders\n");

    for (my $i = 0; $i < $num_coders; $i++) {
        my %c = ();
        $_[0]->Read($buff, 1);
        my $b = ord($buff);
        my $methodsize = $b & 0xF;
        my $iscomplex = ($b & 0x10) == 0x10;
        my $hasattributes = ($b & 0x20) == 0x20;
        if($methodsize > 0){
           $_[0]->Read($buff, $methodsize);
           $c{"method"} = $buff;
        }
        else{
           $c{"method"} = "\0";
        }
        if($iscomplex){
            $c{"numinstreams"} = ReadUInt64($_[0]);
            $c{"numoutstreams"} = ReadUInt64($_[0]);
        }
        else{
            $c{"numinstreams"} = 1;
            $c{"numoutstreams"} = 1;
        }
        $totalin += $c{"numinstreams"};
        $totalout += $c{"numoutstreams"};
        if($hasattributes){
            my $proplen = ReadUInt64($_[0]);
            $_[0]->Read($buff, $proplen);
            $c{"properties"} = $buff;
        }
        else {
            $c{"properties"} = undef;
        }
        $et->VPrint(0, "Reading coder $i\n");
        push(@{ $out_folder{"coders"} }, \%c);
    }
    my $num_bindpairs = $totalout - 1;
    for (my $i = 0; $i < $num_bindpairs; $i++) {
        my @bond = (ReadUInt64($_[0]), ReadUInt64($_[0]));
        push(@{ $out_folder{"bindpairs"} }, @bond);
    }
    my $num_packedstreams = $totalin - $num_bindpairs;
    if($num_packedstreams == 1){
        for (my $i = 0; $i < $totalin; $i++) {
            if(findInBinPair(\@{ $out_folder{"bindpairs"} }, $i) < 0){
                push(@{ $out_folder{"packed_indices"} }, $i);
            }
        }
    }
    else{
        for (my $i = 0; $i < $num_packedstreams; $i++) {
            push(@{ $out_folder{"packed_indices"} }, ReadUInt64($_[0]));
        }
    }

    return \%out_folder;
}

sub RetrieveCodersInfo{
    my $et = shift;
    my $buff;
    my @folders = @{ $_[1] };

    $_[0]->Read($buff, 1);
    my $pid = ord($buff);

    if($pid != 0x0c){ # coders unpack size id expected
        return 0;
    }
    foreach my $folder (@folders) {
        $folder->{"unpacksizes"} = ();
        foreach my $c (@{ $folder->{"coders"} }) {
            for (my $i = 0 ; $i < $c->{"numoutstreams"} ; $i++) {
                push(@{ $folder->{"unpacksizes" } }, ReadUInt64($_[0]));
            }
        }
    }
    $_[0]->Read($buff, 1);
    $pid = ord($buff);

    if($pid == 0x0a){  #crc
        my $numfolders = scalar(@folders);
        $et->VPrint(0, "Number of folders: $numfolders\n");
        my @defined = ReadBoolean($_[0], $numfolders, 1);
        my @crcs;
        foreach my $crcexist (@defined) {
            if($crcexist){
                push(@crcs, ReadUInt32($_[0]));
            }
        }
        for (my $i = 0 ; $i < $numfolders ; $i++) {
            $folders[$i]->{"digestdefined"} = $defined[$i];
            $folders[$i]->{"crc"} = $crcs[$i];
        }
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }

    if($pid != 0x00){ # end id expected
        $et->VPrint(0, "Invalid PID: $pid\n");
        return 0;
    }
    return 1;
}

sub ReadUnpackInfo {
    my $et = shift;
    my $buff;
    my %out_unpackinfo = ();

    $_[0]->Read($buff, 1);
    my $pid = ord($buff);

    if($pid != 0xb) {  # folder id expected
        return 0;
    }

    $out_unpackinfo{"numfolders"} = ReadUInt64($_[0]);
    $out_unpackinfo{"folders"} = ();

    $_[0]->Read($buff, 1);
    my $external = ord($buff);

    if($external == 0x00){
        for (my $i = 0 ; $i < $out_unpackinfo{"numfolders"}; $i++) {
            $et->VPrint(0, "Reading folder $i\n");
            my $folder = ReadFolder($et, $_[0]);
            push(@{ $out_unpackinfo{"folders"} }, $folder);
        }
    }
    return 0 unless RetrieveCodersInfo($et, $_[0], $out_unpackinfo{"folders"});
    return \%out_unpackinfo;
}

sub ReadSubstreamsInfo {
    my $et = shift;
    my $buff;
    my %out_substreamsinfo = ();
    $out_substreamsinfo{"num_unpackstreams_folders"} = ();

    my $numfolders = $_[1];
    my $folders = $_[2];

    $_[0]->Read($buff, 1);
    my $pid = ord($buff);
    if($pid == 13){  # num unpack stream
        $et->VPrint(0, "Num unpack stream detected.\n");
        for (my $i = 0 ; $i < $numfolders; $i++) {
            push(@{ $out_substreamsinfo{"num_unpackstreams_folders"} }, ReadUInt64($_[0]));
        }
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    else{
        @{ $out_substreamsinfo{"num_unpackstreams_folders"} } = (1)x$numfolders;
    }
    if($pid == 9){  # size property
        $et->VPrint(0, "Size property detected.\n");
        $out_substreamsinfo{"unpacksizes"} = ();
        for(my $i=0; $i< scalar(@{ $out_substreamsinfo{"num_unpackstreams_folders"} }); $i++){
            my $totalsize = 0;
            for(my $j=1; $j < @{ $out_substreamsinfo{"num_unpackstreams_folders"} }[$i]; $j++){
                my $size = ReadUInt64($_[0]);
                push(@{ $out_substreamsinfo{"unpacksizes"} }, $size);
                $totalsize += $size;
            }
            # self.unpacksizes.append(folders[i].get_unpack_size() - totalsize)
        }
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    my $num_digests = 0;
    my $num_digests_total = 0;
    for (my $i = 0 ; $i < $numfolders; $i++) {
        my $numsubstreams = @{ $out_substreamsinfo{"num_unpackstreams_folders"} }[$i];
        if($numsubstreams != 1 or not @{ $folders }[$i]->{"digestdefined"}){
            $num_digests += $numsubstreams;
        }
        $num_digests_total += $numsubstreams;
    }
    $et->VPrint(0, "Num Digests Total: $num_digests_total\n");
    if($pid == 10) {  # crc property
        $et->VPrint(0, "CRC property detected.\n");
        my @crcs;
        my @defined = ReadBoolean($_[0], $num_digests, 1);
        foreach my $crcexist (@defined) {
            push(@crcs, ReadUInt32($_[0]));
        }
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    if($pid != 0x00){ # end id expected
        return 0;
    }
    return \%out_substreamsinfo;
}

sub ReadStreamsInfo {
    my $et = shift;
    my $buff;
    my $unpackinfo;
    my %out_streamsinfo = ();

    $_[0]->Read($buff, 1);
    my $pid = ord($buff);
    if($pid == 6){  # pack info
        my $packinfo = ReadPackInfo($et, $_[0]);
        return 0 unless $packinfo;
        $out_streamsinfo{"packinfo"} = $packinfo;
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    if($pid == 7) {  # unpack info
        $et->VPrint(0, "Unpack info data detected.\n");
        $unpackinfo = ReadUnpackInfo($et, $_[0]);
        return 0 unless $unpackinfo;
        $out_streamsinfo{"unpackinfo"} = $unpackinfo;
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    if($pid == 8){  # substreams info
        $et->VPrint(0, "Substreams info data detected.\n");
        my $substreamsinfo = ReadSubstreamsInfo($et, $_[0], $unpackinfo->{"numfolders"}, $unpackinfo->{"folders"});
        return 0 unless $substreamsinfo;
        $out_streamsinfo{"substreamsinfo"} = $substreamsinfo;
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    if($pid != 0x00){ # end id expected
        $et->VPrint(0, "Invalid PID: $pid\n");
        return 0;
    }
    return \%out_streamsinfo;
}

sub IsNativeCoder {
    my $coder = $_[0];

    if(ord(substr($coder->{"method"}, 0, 1)) == 3){
        if(ord(substr($coder->{"method"}, 1, 1)) == 1) {
            if(ord(substr($coder->{"method"}, 2, 1)) == 1) {
                return "LZMA";
            }
        }
    }
    elsif(ord(substr($coder->{"method"}, 0, 1)) == 6){
        if(ord(substr($coder->{"method"}, 1, 1)) == 0xf1) {
            if(ord(substr($coder->{"method"}, 2, 1)) == 7) {
                if(ord(substr($coder->{"method"}, 3, 1)) == 1) {
                    return "7zAES";
                }
            }
        }
    }
}

sub GetDecompressor {
    my $et = shift;

    my $folder = $_[0];
    my %out_decompressor = ();
    $out_decompressor{"chain"} = ();
    $out_decompressor{"input_size"} = $_[1];
    $out_decompressor{"_unpacksizes"} = $folder->{"unpacksizes"};
    @{ $out_decompressor{"_unpacked"} } = (0) x scalar(@{ $out_decompressor{"_unpacksizes"} });
    $out_decompressor{"consumed"} = 0;
    $out_decompressor{"block_size"} = 32768;
    $out_decompressor{"_unused"} = [];

    foreach my $coder (@{ $folder->{"coders"} }) {
       my $algorithm = IsNativeCoder($coder);
       if($algorithm eq "7zAES") {
           $et->Warn("File is encrypted.", 0);
           return 0;
       }
       else{
           push(@{ $out_decompressor{"chain"} }, $algorithm);
       }
    }

    return \%out_decompressor;
}

sub ReadData {
    my $et = shift;
    my $decompressor = $_[1];
    my $rest_size = $decompressor->{"input_size"} - $decompressor->{"consumed"};
    my $unused_s = scalar(@{ $decompressor->{"_unused"} });
    my $read_size = $rest_size - $unused_s;
    my $data = "";
    if($read_size > $decompressor->{"block_size"} - $unused_s){
        $read_size = $decompressor->{"block_size"} - $unused_s;
    }
    if($read_size > 0){
        $decompressor->{"consumed"} += $_[0]->Read($data, $read_size);
        $et->VPrint(0, "Compressed size: $read_size\n");
    }
    return $data;
}

sub Decompress_Internal {
    my $data = "";
    for(my $i=0; $i < scalar(@{ $_[0]->{"chain"} }); $i++){
        if(@{ $_[0]->{"_unpacked"} }[$i] < @{ $_[0]->{"_unpacksizes"} }[$i]){
            my %opts = ();
            $opts{"Filter"} = Lzma::Filter::Lzma1();
            my ($z, $status) = Compress::Raw::Lzma::RawDecoder->new( %opts );
            $status = $z->code($_[1], $data);
            @{ $_[0]->{"_unpacked"} }[$i] += length($data);
        }
    }
    return $data;
}

sub Decompress {
    my $et = shift;
    my $max_length = $_[1];
    my $data = ReadData($et, $_[0], $_[1]);
    my $tmp = Decompress_Internal($_[1], $data);
    return $tmp;
}

sub ReadName {
    my $numfiles = $_[1];

    for(my $i=0; $i < $numfiles; $i++){
        @{ $_[2] }[$i]->{"filename"} = ReadUTF16($_[0]);
    }
}

sub ReadTimes {
    my $et = shift;
    my $external;
    my $numfiles = $_[1];
    my $name = $_[2];

    my @defined = ReadBoolean($_[0], $numfiles, 1);
    $_[0]->Read($external, 1);
    if(ord($external) != 0){
        $et->Warn("Invalid or corrupted file. (ReadTimes)");
        return 0;
    }

    for(my $i=0; $i < $numfiles; $i++){
        if($defined[$i]){
            my $value = ReadRealUInt64($_[0]);
            $value = $value / 10000000.0 - 11644473600;
            @{ $_[3] }[$i]->{$name} = $value;
        }
        else{
            @{ $_[3] }[$i]->{$name} = undef;
        }
    }
}

sub ReadAttributes {
    my $numfiles = $_[1];

    for(my $i=0; $i < $numfiles; $i++){
        if($_[2][$i]){
            my $value = ReadUInt32($_[0]);
            @{ $_[3] }[$i]->{"attributes"} = $value >> 8;
        }
        else{
            @{ $_[3] }[$i]->{"attributes"} = undef;
        }
    }
}

sub ReadFilesInfo {
    my $et = shift;
    my $buff;

    my $numfiles = ReadUInt64($_[0]);
    my @out_files = ();
    for(my $i = 0; $i < $numfiles; $i++){
        my %new_file = ();
        $new_file{"emptystream"} = 0;
        push(@out_files, \%new_file);
    }
    my $numemptystreams = 0;
    $et->VPrint(0, "Number of files: $numfiles\n");
    while(1){
        $_[0]->Read($buff, 1);
        my $prop = ord($buff);
        if($prop == 0){  # end
            return \@out_files;
        }
        my $size = ReadUInt64($_[0]);
        if($prop == 25) {  # dummy
            $_[0]->Seek($size, 1);
            next;
        }
        $_[0]->Read($buff, $size);
        my $buffer = new File::RandomAccess(\$buff);
        if($prop == 14){  # empty stream
            my @isempty = ReadBoolean($buffer, $numfiles, 0);
            my $numemptystreams = 0;
            for(my $i = 0; $i < $numfiles; $i++){
                if($isempty[$i] == 0){
                    $out_files[$i]->{"emptystream"} = 0;
                }
                else{
                    $out_files[$i]->{"emptystream"} = 1;
                    $numemptystreams++;
                }
            }
        }
        elsif($prop == 15) {  # empty file

        }
        elsif($prop == 17){  # name
            $et->VPrint(0, "Name prop detected.\n");
            my $external;
            $buffer->Read($external, 1);
            my $is_external = ord($external);
            if($is_external == 0){
                ReadName($buffer, $numfiles, \@out_files);
            }
        }
        elsif($prop == 20){  # last write time
            $et->VPrint(0, "Last write time detected.\n");
            ReadTimes($et, $buffer, $numfiles, "lastwritetime", \@out_files);
        }
        elsif($prop == 21){  # attributes
            $et->VPrint(0, "File attributes detected.\n");
            my $external;
            my @defined = ReadBoolean($buffer, $numfiles, 1);
            $_[0]->Read($external, 1);
            if(ord($external) == 0){
                ReadAttributes($buffer, $numfiles, \@defined, \@out_files);
            }
            else{
                my $dataindex = ReadUINT64($buffer);
                #TODO: try to read external data
            }
        }
    }
}

sub ExtractHeaderInfo {
    my $et = shift;
    my $buff;
    my %out_headerinfo = ();
    $out_headerinfo{"files_info"} = ();
    my $files_info;

    $_[0]->Read($buff, 1);
    my $pid = ord($buff);

    if($pid == 0x04){
        my $mainstreams = ReadStreamsInfo($et, $_[0]);
        if($mainstreams == 0){
            $et->Warn("Invalid or corrupted file. (ExtractHeaderInfo)");
            return 0;
        }
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    if($pid == 0x05){
        $et->VPrint(0, "File info pid reached.\n");
        $files_info = ReadFilesInfo($et, $_[0]);
        push(@{ $out_headerinfo{"files_info"} }, $files_info);
        $_[0]->Read($buff, 1);
        $pid = ord($buff);
    }
    if($pid != 0x00){ # end id expected
        $et->VPrint(0, "Invalid PID: $pid\n");
        return 0;
    }
    return \%out_headerinfo;
}

sub DisplayFiles {
   my $et = shift;
   my $docNum = 0;
   my $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::RAR5');

   foreach my $currentfile (@{ $_[0] }){
       $$et{DOC_NUM} = ++$docNum;
       $et->HandleTag($tagTablePtr, 'ModifyDate', $currentfile->{"lastwritetime"});
       $et->HandleTag($tagTablePtr, 'ArchivedFileName', $currentfile->{"filename"});
   }
   delete $$et{DOC_NUM};
   if($docNum > 1 and not $et->Options('Duplicates')){
      $et->Warn("Use the Duplicates option to extract tags for all $docNum files", 1);
   }
}

#------------------------------------------------------------------------------
# Extract information from a 7z file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid 7z file
sub Process7Z($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($flags, $buff);

    return 0 unless $raf->Read($buff, 6) and $buff eq "7z\xbc\xaf\x27\x1c";

    $et->SetFileType();

    $raf->Read($buff, 2);
    my ($major_version, $minor_version) = unpack('cc', $buff);
    my $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::RAR5');
    $et->HandleTag($tagTablePtr, 'FileVersion', sprintf('7z v%d.%.2d',$major_version,$minor_version));

    $raf->Seek(4, 1);  # skip Start Header CRC

    $raf->Read($buff, 20);
    my ($nextheaderoffset, $nextheadersize) = unpack('QQx', $buff);
    $et->VPrint(0, "NextHeaderOffset: $nextheaderoffset, NextHeaderSize: $nextheadersize\n");

    $raf->Seek($nextheaderoffset, 1);  # going to next header offset
    $raf->Read($buff, 1);
    my $pid = ord($buff);
    if($pid == 1){  # normal header
        $et->VPrint(0,"Normal header detected. trying to decode\n");
        my $headerinfo = ExtractHeaderInfo($et, $raf);
        if($headerinfo == 0){
            $et->Warn("Invalid or corrupted file.");
            return 1;
        }
        DisplayFiles($et, @{ $headerinfo->{"files_info"} });
    }
    elsif($pid == 23){  # encoded header
        unless (eval { require Compress::Raw::Lzma }) {
            $et->Warn("Install Compress::Raw::Lzma to read encoded 7z information");
            return 1;
        }
        $et->VPrint(0, "Encoded Header detected. trying to decode\n");
        my $streamsinfo = ReadStreamsInfo($et, $raf);
        if($streamsinfo == 0){
            $et->Warn("Invalid or corrupted file.");
            return 1;
        }
        my $buffer2 = ();
        foreach my $folder (@{ $streamsinfo->{"unpackinfo"}->{"folders"} }) {
            my @uncompressed = @{ $folder->{"unpacksizes"} };
            my $compressed_size = $streamsinfo->{"packinfo"}->{"packsizes"}[0];
            my $uncompressed_size = @uncompressed[scalar(@uncompressed) - 1];
            my $decomporessor = GetDecompressor($et, $folder, $compressed_size);
            if($decomporessor == 0){
                $et->Warn("Invalid or corrupted file.");
                return 1;
            }

            my $src_start = 32;
            $src_start += $streamsinfo->{"packinfo"}->{"packpos"};
            $raf->Seek($src_start, 0);
            my $remaining = $uncompressed_size;
            my $folder_data = "";
            while($remaining > 0){
                $folder_data .= Decompress($et, $raf, $decomporessor, $remaining);
                $remaining = $uncompressed_size - length($folder_data);
            }
            $buffer2 = new File::RandomAccess(\$folder_data);
        }
        $buffer2->Seek(0, 0);
        $buffer2->Read($buff, 1);
        $pid = ord($buff);
        if($pid != 0x01){ # header field expected
            return 0;
        }
        my $headerinfo = ExtractHeaderInfo($et, $buffer2);
        if($headerinfo == 0){
            $et->Warn("Invalid or corrupted file.");
            return 1;
        }
        DisplayFiles($et, @{ $headerinfo->{"files_info"} });
    }else{  # Unknown header
        return 0;
    }

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::7Z - Read 7z archives

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from 7z archives.

=head1 AUTHOR

Copyright 2023, Amir Gooran

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://py7zr.readthedocs.io/en/latest/archive_format.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ZIP RAR5 Tags>

=cut

