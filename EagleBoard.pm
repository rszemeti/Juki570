#!/usr/bin/perl 

use warnings;
use strict;



use XML::Hash;
use DBI;

package EagleBoard;

use Data::Dumper qw/Dumper/;

sub new{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
 
    return $self;
}

sub setFileName {
    my ( $self, $fileName ) = @_;
    $self->{_fileName} = $fileName if defined($fileName);
    return $self->{_fileName};
}

sub getFileName {
    my ( $self, $fileName ) = @_;
    return $self->{_fileName};
}

sub getTitle{
  my($self)=shift;
  my($title) = $self->{_fileName} =~ /(.*)\.brd$/i;
  return $title;
}

sub process{
  my( $self)=@_;
  if(! $self->{_fileName} =~ /\w+.BRD$/i){
    die "Use:  reader.pl <eagle .BRD file>\n";
  }

  open(my $FH, "<".$self->{_fileName}) or die "Can't open ".$self->{_fileName}." for reading: $!\n";

  my($xmlString);
  while(<$FH>){
    $xmlString .= $_;
  }

  close($FH);

  my $xml_converter = XML::Hash->new();
  $self->{_data}= $xml_converter->fromXMLStringtoHash($xmlString);

  my($elements) = $self->{_data}->{eagle}->{drawing}->{board}->{elements}->{element};
  my($library);
  
  foreach my $lib ($self->{_data}->{eagle}->{drawing}->{board}->{libraries}->{library}){
     if(ref($lib) eq 'HASH'){
        $lib = [$lib];
     }
     foreach my $l2 (@{$lib}){
       if(ref($l2->{packages}->{package}) eq 'HASH'){
          my($t)=$l2->{packages}->{package};
          $l2->{packages}->{package} =[];
          $l2->{packages}->{package}->[0]=$t;
       }
       foreach my $pack (@{$l2->{packages}->{package}}){
         $library->{$l2->{name}}->{$pack->{name}}={};
         if($pack->{smd}){
           $library->{$l2->{name}}->{$pack->{name}}->{isSmd}=1;
         }else{
           $library->{$l2->{name}}->{$pack->{name}}->{isSmd}=0;
         }
       }
     }
  }
  
  $self->{_library}=$library;
  #print Dumper($library);

  my($feeders)={};
  my(@feederList);
  
  my($dbh) = DBI->connect('DBI:mysql:components', 'root', 'wibble'
	           ) || die "Could not connect to database: $DBI::errstr";
               
  my($sth) = $dbh->prepare('SELECT * FROM packages WHERE library=? AND package=?',undef);
  my($sth2) = $dbh->prepare('SELECT * FROM components WHERE packageId=? AND value=?',undef);

  my($smdComponents) = [];
  my($handInsertions) = [];
  
  if(ref($elements) eq 'HASH'){
    $elements = [$elements];
  }
  
  for(my $i=0;$i<scalar(@{$elements});$i++){
    push(@{$smdComponents},$elements->[$i]);
  }

  # normalise the components
  for(my $i=0;$i<scalar(@{$elements});$i++){
    #print $library->{$elements->[$i]->{library}};
   # next unless (exists($elements->[$i]->{package}->{smd}));
    $elements->[$i]->{value} = uc($elements->[$i]->{value});
    if(! $elements->[$i]->{value} =~ /\w+/){
      $elements->[$i]->{value}='unknown';
    }
    if(exists($elements->[$i]->{rot})){
      my($rot) = $elements->[$i]->{rot} =~/R(\d+)/;
      $elements->[$i]->{rotation} = $rot;
    }else{
      $elements->[$i]->{rotation}=0;
    }
    # convert 100N to 100NF
    if($elements->[$i]->{value} =~ /^\d+NF$/){
      $elements->[$i]->{value} =~ s/NF/N/;
    }
    if($elements->[$i]->{value} =~ /^\d\.\d+N$/){
      $elements->[$i]->{value} =~ s/^(\d+)\.(\d+)N/($1)N($3)/;
    }
    # $elements->[$i]->{key} = $elements->[$i]->{library}."_".$elements->[$i]->{package}."_".$elements->[$i]->{value};
    $elements->[$i]->{key} = $elements->[$i]->{package}."_".$elements->[$i]->{value};
    
    $sth->execute($elements->[$i]->{library},$elements->[$i]->{package});
    my($result) = $sth->fetchrow_hashref();
  
    if($result){
      $elements->[$i]->{packageData} = $result;
      # print "found ".$result->{id}."\n";
    }else{
      print "creating new package for device ".$elements->[$i]->{key}."\n";
      if($elements->[$i]->{package} =~ /0805/){
        $dbh->do('INSERT INTO packages SET smd=TRUE, library=?, width=2.0, length=1.3,  package=?',undef,$elements->[$i]->{library},$elements->[$i]->{package});
      }elsif($elements->[$i]->{package} =~ /0603/){
        $dbh->do('INSERT INTO packages SET smd=TRUE, library=?, width=1.5, length=0.8 package=?',undef,$elements->[$i]->{library},$elements->[$i]->{package});
      }else{
        $dbh->do('INSERT INTO packages SET smd=TRUE, library=?, package=?',undef,$elements->[$i]->{library},$elements->[$i]->{package});
      }
      $dbh->do('INSERT INTO packages SET smd=TRUE, library=?, package=?',undef,$elements->[$i]->{library},$elements->[$i]->{package});
      $sth->execute($elements->[$i]->{library},$elements->[$i]->{package});
      my($result) = $sth->fetchrow_hashref();
      $elements->[$i]->{packageData} = $result;
    }
   
    $sth2->execute($elements->[$i]->{packageData}->{id},$elements->[$i]->{value});
    my($result2) = $sth2->fetchrow_hashref();
    
    if($result2){
      $elements->[$i]->{componentData} = $result2;
      # print "found ".$result->{id}."\n";
    }else{
      print "creating new component ".$elements->[$i]->{value}."\n";
      $dbh->do('INSERT INTO components SET packageId=?, value=?',undef,$elements->[$i]->{packageData}->{id},$elements->[$i]->{value});
      $sth2->execute($elements->[$i]->{packageData}->{id},$elements->[$i]->{value});
      my($result2) = $sth2->fetchrow_hashref();
      $elements->[$i]->{componentData} = $result2;
    }
  }
  

# sort
my(@res,@cap,@diode,@transistor,@fids,@rest,@hand);
foreach(@{$elements}){
  my($c)=$_;
  ($c->{sortOrder}) =$c->{name} =~ /^[RCDT](\d+)$/;
  if($library->{$c->{library}}->{$c->{package}}->{isSmd} == 0){
    push(@hand,$c);
  }elsif($c->{componentData}->{mountable} eq 'N'){
     push(@hand,$c);
  }elsif($c->{name} =~ /^R\d+$/){
    push(@res,$c);
  }elsif($c->{name} =~ /^C\d+$/){
    push(@cap,$c);
  }elsif($c->{name} =~ /^D\d+$/){
    push(@diode,$c);
  }elsif($c->{name} =~ /^T\d+$/){
    push(@transistor,$c);
  }elsif($c->{name} =~ /^FID\d+$/){
    push(@fids,$c);
  }else{
    ($c->{sortOrder}) =$c->{name} =~ /^\D+(\d+)$/;
    push(@rest,$c);
  }
  # values ...
  # find the 3N3, 2K7 etc style ones
  if($c->{value} =~ /^\d+(R|K|M|U|UF|N|NF|P|PF)\d*$/){
    my($t,$mul,$u) = $c->{value} =~ /^(\d+)(R|K|M|U|UF|N|NF|P|PF)(\d*)$/;
    if($u eq ""){$u = 0;}
    my($val) = $t+$u/10;
    if($mul =~/^(R|P|PF)$/){
      # $val is fine * 1
    }elsif($mul =~/^(K|N|NF)$/){
      $val *= 1000;
    }elsif($mul =~/^(M|U|UF)$/){
      $val *= 1000000;
    }
    $c->{valueOrder}=$val;
    #print $c->{value}." IS ".$val."\n";
  }elsif($c->{value} =~ /^\d+\.\d+(R|K|M|U|UF|N|NF|P|PF)$/){
    my($t,$u,$mul) = $c->{value} =~ /^(\d+)\.(\d+)(R|K|M|U|UF|N|NF|P|PF)/;
    if($u eq ""){$u = 0;}
    my($val) = $t+$u/10;
    if($mul =~/^(R|P|PF)$/){
      # $val is fine * 1
    }elsif($mul =~/^(K|N|NF)$/){
      $val *= 1000;
    }elsif($mul =~/^(M|U|UF)$/){
      $val *= 1000000;
    }
    $c->{valueOrder}=$val;
    #print $c->{value}." IS2 ".$val."\n";
  }else{
    #print $c->{value}." NOT\n";
    # put odd ones at the end.
    $c->{valueOrder}=1000000000;
  }
 }
 

 #  sorted by component ID
 my(@mountable);
 push(@mountable, sort { $a->{sortOrder} <=> $b->{sortOrder} } @res);
 push(@mountable, sort { $a->{sortOrder} <=> $b->{sortOrder} } @cap);
 push(@mountable, sort { $a->{sortOrder} <=> $b->{sortOrder} } @diode);
 push(@mountable, sort { $a->{sortOrder} <=> $b->{sortOrder} } @transistor);
 push(@mountable, sort { $a->{sortOrder} <=> $b->{sortOrder} } @rest);
 
 # Sorted by vlaue for generating a sensible feeder list.
 my(@feederOrder);
 push(@feederOrder, sort { $a->{valueOrder} <=> $b->{valueOrder} } @res);
 push(@feederOrder, sort { $a->{valueOrder} <=> $b->{valueOrder} } @cap);
 push(@feederOrder, sort { $a->{sortOrder} <=> $b->{sortOrder} } @diode);
 push(@feederOrder, sort { $a->{sortOrder} <=> $b->{sortOrder} } @transistor);
 push(@feederOrder, sort { $a->{sortOrder} <=> $b->{sortOrder} } @rest);
 
## First, scan the element list and generate a list of feeders and pop the element into a little list.;
foreach(@feederOrder){
  my($c)=$_;
  my($isSmd)=0;
  
  # print $c->{name}." ".$c->{value}." (".$c->{x}.",".$c->{y}.")\n";
  if(exists($feeders->{$c->{key}})){
    $feederList[$feeders->{$c->{key}}]->{count}++;
    push(@{$feederList[$feeders->{$c->{key}}]->{usedBy}},$c->{name});
  }else{
    #print "New Feeder for ".$c->{value}." ";
    my($feeder)={ 
      'count' => 1,
      'name' => $c->{value},
      'pattern' => $c->{package},
      'usedBy' =>[$c->{name}],
      'packageData' =>$c->{packageData},
    };
    if(exists($c->{attribute})){
      # check for MPN(can be hashref, can be array ref)
      #print Dumper($c->{attribute});
    }
    push(@feederList,$feeder);
    $feeders->{$c->{key}} = scalar(@feederList) -1;
    #print "Saved '".$c->{key}."' in slot ".$feeders->{$c->{key}}."\n";
   }
}

 $self->{_placements} = \@mountable;
 $self->{_feeders} = $feeders;
 $self->{_feederList} = \@feederList;
 $self->{_fids} =\@fids;
 $self->{_hand} =\@hand;

}

sub getFeederList {
    my( $self ) = @_;
    return $self->{_feederList};
}

sub getMountable{
    my( $self ) = @_;
    return $self->{_placements};
}

sub getHandInsertions{
    my( $self ) = @_;
    return $self->{_hand};
}

sub getFids{
    my( $self ) = @_;
    return $self->{_fids};
}

sub getFeederIndex{
  my($self)=shift;
  return $self->{_feeders};
}
1;