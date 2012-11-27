package SMcli;

use strict;
use warnings;
use File::Temp;
use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use SMcli ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.04';


# Preloaded methods go here.

sub new {
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  my $self = { debug => 0,
               pass => '',
               @_ };
  bless ($self,$class);
  return $self;
}


###############################################################
# Method: healthStatus                                        #
#                                                             #
# Queries storage subsystem status                            #
# Returns: 0 if subsystem is OK                               #
#          Array reference to output if a problem is detected #
###############################################################
sub healthStatus {
  my $self = shift;

  my @output = $self->runCmd('show storageArray healthStatus');
  foreach my $line (@output) {
    #if ($line =~ /^Storage array health status = (.+)\.$/) {
    if ($line =~ /^Storage array health status = optimal\.$/) {
      return 0;
   }
  }
  return \@output;
}


###############################################################
# Method: reportStatus                                        #
#                                                             #
# Queries storage subsystem status                            #
# Returns: a hash with the probs                              #
###############################################################
sub reportStatus{
  my $self = shift;
  my %statushash;
  my $component;
  my $status;
  my $location;
  my $counter=0;
  my @health=$self->runCmd('show storageArray healthStatus');
  foreach my $line (@health) {
	chomp $line;
        if ( $line =~ /Component reporting problem:\s+(.+)/ ) {
            $component=$1;
            if ( $health[$counter+1] =~ /\s+Status:(.+)/ ) {
              $status=$1;
            }
	    else { $status="NA"; }
	    if ( $health[$counter+2] =~ /\s+Location:(.+)/ ) {
	      $location=$1;
	    }
	    else { $location = "NA"; }
            if ( $component ) {
              $statushash{$component}{status}=$status;
              $statushash{$component}{location}=$location;
            }
	}
        $counter=$counter+1;
  }
  return \%statushash;
}


##########################################################
# Method: showVirtualDisk
#                                                        #
# Gets information on a logical drive                    #
# Args: logical drive to check                           #
#                                                        #
# Returns: Hash ref with all volume information returned #
##########################################################
sub showVirtualDisk {
  my $self = shift;

  my $logicaldrive=shift;
  $logicaldrive=cleanInput($logicaldrive);
  my %results;
  foreach my $line ($self->runCmd("show virtualDisk [\"$logicaldrive\"]")) {
    next if ($line =~ /^$/ || $line =~ /^ *$/ || $line =~ /^VOLUME DETAILS$/);
    my ($key,$value)= $line =~ /^\s+([^:]+): +(.*)$/;
    next unless defined($key);
    next if $key =~ /^$/;
    next if $key =~ /^$/;
    next if $key =~ /^ *$/;
    $value=~ s/ +$//g;
    $results{$key}=$value;
  }
  return \%results;
}

##########################################################
# Method: showAllVirtualDisks
#                                                        #
# Gets information on all logical drives                 #
#                                                        #
# Returns: Hash ref with all volume information returned #
##########################################################
sub showAllVirtualDisks {
  my $self = shift;

  # hash with hashes
  my %results;
  my $drive = "";
  foreach my $line ($self->runCmd("show allVirtualDisks")) {
    next if ($line =~ /^$/
	|| $line =~ /^ *$/
	|| $line =~ /^VOLUME DETAILS$/
	|| $line =~ /Number of standard logical drives:/
	);
    my ($key,$value)= $line =~ /^\s+([^:]+): +(.*)$/;
    next unless defined($key);
    next if $key =~ /^$/;
    next if $key =~ /^$/;
    next if $key =~ /^ *$/;
    #print "$line\n";
    $value=~ s/ +$//g;
    if($key =~ /Logical Drive name/){
      $drive = $value;
      next;
    }
    $results{$drive}{$key}=$value;
  }
  return \%results;
}

##########################################################
# Method: createVirtualDisk
#                                                        #
# Create a logical drive                                 #
#                                                        #
# Returns: Hash ref with all volume information returned #
##########################################################
# Example syntax:
# create virtualDisk diskGroup=0 raidLevel=6 userLabel="vdisk1" capacity=558.411GB;
sub createVirtualDisk {
  my $self = shift;

  my @args=@_;
  my $cmd="";
  for (my $i=0;$i<$#args;$i+=2)
    {
        $cmd .= " " .quoteArgument(${args}[$i] . "=" . ${args}[$i+1]);
    }
  $cmd="create virtualDisk $cmd";

  foreach my $line ($self->runCmd("$cmd")) {
    next if ($line =~ /^$/
	|| $line =~ /^ *$/
	);
    my ($key,$value)= $line =~ /^\s+([^:]+): +(.*)$/;
    next unless defined($key);
    next if $key =~ /^$/;
    next if $key =~ /^$/;
    next if $key =~ /^ *$/;
  }

}

##########################################################
# Method: deleteVirtualDisk                             #
#                                                        #
# Delete a logical drive                                 #
# Args: logical drive name                               #
#                                                        #
# Returns: 0 on failure, 1 on success                    #
##########################################################
sub deleteVirtualDisk {
  my $self = shift;

  my $logical_drive = shift;
  my $cmd="delete virtualDisk [\"$logical_drive\"]";

  my $status = 1;
  foreach my $line ($self->runCmd("$cmd")) {
    next if $line =~ /^$/;
    $status = 0 if $line =~ /SMcli failed/;
  }
  return $status;
}

##########################################################
# Method: addVirtualDiskMapping
#                                                        #
# Add a logical drive mapping                            #
# Args: logical drive name, logical unit number, host    #
#                                                        #
# Returns: 1 if add succeeded                            #
##########################################################
sub addVirtualDiskMapping {
  my $self = shift;

  my $logical_drive = shift;
  my $logical_unit_number = shift;
  my $host = shift;

  my $cmd="set virtualDisk [\"$logical_drive\"] logicalUnitnumber=$logical_unit_number host=\"$host\"";

  my $status = 1;
  foreach my $line ($self->runCmd("$cmd")) {
    next if ($line =~ /^$/);
    $status = 0 if $line =~ /SMcli failed/;
  }
  return $status;

}

##########################################################
# Method: removeVirtualDiskMapping
#                                                        #
# Remove a logical drive mapping                         #
# Args: logical drive name, host                         #
#                                                        #
# Returns: 1 if add succeeded                            #
##########################################################
sub removeVirtualDiskMapping {
  my $self = shift;

  my $logical_drive = shift;
  my $host = shift;

  my $cmd="remove virtualDisk [\"$logical_drive\"] lunMapping host=\"$host\"";

  my $status = 1;
  foreach my $line ($self->runCmd("$cmd")) {
    next if ($line =~ /^$/);
    $status = 0 if $line =~ /SMcli failed/;
  }
  return $status;

}

##########################################################
# Method: showVirtualDiskMappings                        #
#                                                        #
# Show logical drive mapping of a host                   #
# Args: logical drive name, host                         #
#                                                        #
# Returns: 1 if add succeeded                            #
##########################################################
sub showVirtualDiskMappings {
  my $self = shift;

  my $host = shift;

  my $cmd="show storageArray lunMappings host [\"$host\"]";

  my @mappings;
  foreach my $line ($self->runCmd("$cmd")) {
    next if ($line =~ /^$/);
    next if ($line =~ /^MAPPINGS/);
    next if ($line =~ /Virtual Disk Name/);
    next if ($line =~ /Access Virtual Disk/);
    return 0 if $line =~ /SMcli failed/;
    my %map;
    ($map{'logicaldrive'}, $map{'lunnr'}, $map{'controller'}, $map{'access'}, $map{'status'}) = $line =~ /^\s+([\w\-]+)\s+(\d+)\s+([\w,]+)\s+(\w+ \w+)\s+(\w+)/;
    push(@mappings,\%map);
  }
  return \@mappings;
}


##################################################################
## Method: showController                                        #
##                                                               #
## Shows controller information                                  #
## Args: Optional hash containing: controller => (a | b) or      #
##                                 allControllers => 1 (default) #
##                                 summary => 1                  #
## Returns: Array reference containing command output            #
##################################################################
sub showController {
  my $self = shift;

  my %args=@_;
  my $cmd;
  if (%args) {
    if ($args{controller}) {
      $cmd = " controller [ ". cleanInput($args{controller}) ." ]";
    } else {
      $cmd = " allControllers";
    }
    $cmd .= " summary" if ($args{summary});
  } else {
    $cmd = " allControllers";
  }

  my @output = $self->runCmd("show $cmd");
  foreach my $line (@output) {
    if ($line =~ /^Storage array health status = (.+)\.$/) {
      return 0;
    }
  }
  return \@output;
}


###################################################################################################
## Method: getEvents                                                                              #
##                                                                                                #
## Gets storage array events                                                                      #
## Args: (optional) hash containing eventType: all or critical (defaults to all)                  #
##                                  count:     number of events to get (don't specify to get all) #
## Returns: File::Temp object of the tempfile containing the event log                            #
###################################################################################################
sub getEvents {
  my $self = shift;

  my %args = @_;
  my $type = defined $args{eventType} ? cleanInput($args{eventType}) : "all";
  my $count = defined $args{count} ? "count=". cleanInput($args{count}) : '';
  my $file = new File::Temp;
  my $cmd = "save storageArray ${type}Events file=\"". $file->filename ."\" $count";
  foreach my $line ($self->runCmd($cmd)) {
    next if ($line =~ /^$/);
    warn "Unexpected output in downloading events on Array $self->{array}";
    return 0;
  }
  return $file;
}



###################################################################################################
## Method: getConfig                                                                              #
##                                                                                                #
## Gets storage array configuration                                                               #
## Args: (optional) hash containing any of the following keys:                                    #
##                    globalSettings, volumeConfigAndSettings, hostTopology, lunMappings          #
##                                                                                                #
## Returns: File::Temp object of the tempfile containing the event log                            #
###################################################################################################
sub getConfig {
  my $self = shift;

  my %args = @_;
  my $opts;

  if (%args) {
    foreach my $option (qw/globalSettings volumeConfigAndSettings hostTopology lunMappings/) {
      $opts .= " $option=";
      $opts .= $args{$option} ? "TRUE" : "FALSE";
    }
  } else {
    $opts=" allConfig";
  }

  my $file = new File::Temp;
  my $cmd = "save storageArray configuration file=\"". $file->filename ."\" $opts";
  foreach my $line ($self->runCmd($cmd)) {
    next if ($line =~ /^$/);
    warn "Unexpected output in downloading configuration on Array $self->{array}";
    return 0;
  }
  return $file;
}




##########################################################################################
## Method: monitorPerformance                                                            #
##                                                                                       #
## Monitor's array performance & returns stats                                           #
## Args: Optional Hash containing: interval - seconds between data capture (default: 5)  #
##                                 iterations - # of data points to collect (default: 5) #
## Returns: File::Temp object to file containing performance data                        #
##########################################################################################
sub monitorPerformance {
  my $self = shift;
  my %args = @_;

  my $cmd;
  if (%args) {
    my $int = defined $args{interval} ? $args{interval} : 5;
    $int = $int =~ tr/0-9//cd;

    my $iter = defined $args{iterations} ? $args{iterations} : 5;
    $iter = $iter =~ tr/0-9//cd;

    $cmd = "set performanceMonitor interval=$int iterations=$iter ; ";

  }
  my $file = new File::Temp;
  $cmd .= "upload storageSubsystem file=\"". $file->filename ."\" content=performanceStats";
  foreach my $line ($self->runCmd($cmd)) {
    next if ($line =~ /^$/);
    warn "Unexpected output in downloading configuration on Array $self->{array}";
    return 0;
  }
  return $file;
}





######################################
## Method: stopSnap                  #
##                                   #
## Stops (suspends) a snapshot       #
## Args: Snapshot to stop            #
## Returns: 0 if snapshot stopped OK #
##          1 if problem detected    #
######################################
#sub stopSnap {
#  my $self = shift;
#
#  my $vol=shift;
#  $vol=cleanInput($vol);
#  foreach my $line ($self->runCmd("stop snapshot volume [\"$vol\"]")) {
#    next if ($line =~ /^$/);
#    warn "Unexpected output in stopping snapshot $vol on Array $self->{array}";
#    return 1;
#  }
#
#  return 0;
#}
#
#
#
########################################
## Method: recreateSnap                #
##                                     #
## Recreates a snapshot                #
## Args: Snapshot to recreate          #
## Returns: 0 if snapshot recreated OK #
##          1 if problem detected      #
########################################
#sub recreateSnap {
#  my $self = shift;
#
#  my $vol=shift;
#  $vol=cleanInput($vol);
#  foreach my $line ($self->runCmd("recreate snapshot volume [\"$vol\"]")) {
#    next if ($line =~ /^$/);
#    warn "Unexpected output in recreating snapshot $vol on Array $self->{array}";
#    return 1;
#  }
#
#  return 0;
#}
#
#
#
##########################################################
## Method: suspendRVM                                    #
##                                                       #
## Suspends an RVM mirror (must be run on primary array) #
## Args: Primary side of mirror to the suspended         #
## Returns: 0 if successful                               #
##          1 if problem detected                        #
##########################################################
#sub suspendRVM {
#  my $self = shift;
#
#  my $vol=shift;
#  $vol=cleanInput($vol);
#  foreach my $line ($self->runCmd("suspend remoteMirror primary [\"$vol\"]")) {
#    next if ($line =~ /^$/);
#    warn "Unexpected output in suspending RVM  mirror $vol on Array $self->{array}";
#    return 1;
#  }
#
#  return 0;
#}
#
#
#
#
#########################################################
## Method: resumeRVM                                    #
##                                                      #
## Resumes an RVM mirror (must be run on primary array) #
## Args: Primary side of mirror to the resumed          #
## Returns: 0 if successful                              #
##          1 if problem detected                       #
#########################################################
#sub resumeRVM {
#  my $self = shift;
#
#  my $vol=shift;
#  foreach my $line ($self->runCmd("resume remoteMirror primary [\"$vol\"]")) {
#    next if ($line =~ /^$/);
#    warn "Unexpected output in resuming RVM mirror $vol on Array $self->{array}";
#    return 1;
#  }
#
#  return 0;
#}
#



#########################################################
# Method: runCmd                                        #
#                                                       #
# Builds and runs an SMcli command                      #
# Args: smcli string to run                             #
#                                                       #
# Returns: Array containing all SMcli output            #
# This should not be called from outside of this module #
#########################################################
sub runCmd {
  my $self=shift;
  my $smcli_string=shift;
  my $cmd;

  if ( $self->{subsystem} =~ /\d+\.\d+\.\d+\.\d+/ ) {
    $cmd = "SMcli $self->{subsystem} ";
  }
  else {
    $cmd = "SMcli -n $self->{subsystem} ";
  }

  $cmd .= "-p $self->{pass} " if ($self->{pass});
  $cmd .= "-c '$smcli_string;'";

  print "$cmd\n" if ($self->{debug});

  open SMCLI,"$cmd 2>&1 |" or die "Can't run SMcli: $!";
  my (@return,$data);
  while (<SMCLI>) {
    print $_ if ($self->{debug});
    $data = 0 if (/Script execution complete.$/);
    push @return,$_ if ($data);
    warn "SMcli error" if (/^SMcli failed.$/);
    $data=1 if (/^Executing script...$/);
  }
  close SMCLI;

  return @return;
}



############################################################################
# Method: cleanInput                                                       #
#                                                                          #
# Makes a stab at cleaning up input before it's passed to the command line #
# Args: String to clean                                                    #
#                                                                          #
# Returns: Cleaned string                                                  #
############################################################################
sub cleanInput {
  my $string=shift;
  $string =~ tr/-_+A-Za-z0-9//cd;
  return $string;
}

############################################################################
# Method: quoteArgument                                                    #
#                                                                          #
# Makes a stab at quoting a cmd line argument before it's passed to the    # 
# command line                                                             #
# Args: String to quote
#                                                                          #
# Returns: Quoted cmd line string, if necessary                            #
############################################################################
sub quoteArgument {
  my $string=shift;
  my ($k, $v) = split(/=/,$string);
  # value already quoted
  my $r=$string;
  $r = $string if $v =~/^".*"$/;
  # values that need to quoted:
  $r = "$k=\"$v\"" if $k =~/userLabel/i;
  # ...
  print "$r\n";
  return $r;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME


SANtricity::SMcli - Perl extension to manipulate SAN controllers using SANtricity
Command Line

=head1 SYNOPSIS

  use SMcli;

  my $subsystem = SMcli->new(subsystem=> "subsystemname");

  # Check health status
  my $status = $subsystem->healthStatus();
  if ($status != 0) {
    print @$status;
  }


=head1 DESCRIPTION

SANtricity::SMcli is a perl interface to Engenio's SMcli.  It is also
used in the Dell Powervault MD storage series.  This release has been tested with
SMcli version 10.80.G6.47 on GNU/Linux - it will probably work on any
Unix system (and maybe windows), but some functions probably won't
work with other versions of Santricity due to syntax changes. It
currently offers a fairly small number of commands, which may be
expanded as time and motivation allow.

All methods given here run the SMcli binary, so you need the correct
permissions (or be root). Obviously it's quite possible to break your
array configuration using the command line and therefore with this
module. Things seem to work OK for me but there's no guarantee.

=head2 CONSTRUCTOR

new(subsystem => 'SUBSYSTEMNAME', OPTIONS)
    Creates a new SMcli object. SUBSYSTEMNAME is the name of 
    the storage subsystem (SMcli -d shows all defined arrays).

    OPTIONS can be:

    pass => 'PASSWORD'
          Use a password.

    debug => 1
          Enable some debugging output in the SMcli calls.

=head2 METHODS

    healthStatus
    reportStatus
    showVirtualDisk
    showAllVirtualDisks
    createVirtualDisk
    deleteVirtualDisk
    addVirtualDiskMapping
    removeVirtualDiskMapping
    showVirtualDiskMappings
    showController
    getEvents
    getConfig
    monitorPerformance

=head2 EXPORT

None by default.

=head1 SEE ALSO

...

=head1 AUTHOR

Rich Bishop, E<lt>rjb@cpan.orgE<gt>; Rudy Gevaert, <Rudy.Gevaert@UGent.be>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Rich Bishop
Copyright (C) 2010,2012 by Rudy Gevaert

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut

