set ns [new Simulator]

Agent/TCP/FullTcp set segsize_ 1460
Agent/TCP/FullTcp set windowInit_ 10
Agent/TCP/FullTcp set tcpTick_ 0.01
set bw 1000Mb
set nums 32
set datasize [expr 1460 * 5]
set reqsize 100
set bufsize 1024
set rto 0.2

$ns color 1 red
$ns color 2 blue
$ns color 3 cyan
$ns color 4 green
$ns color 5 orange
$ns color 6 black
$ns color 7 yellow
$ns color 8 purple
$ns color 9 gold
$ns color 10 chocolate
$ns color 11 brown
$ns color 12 tan
$ns color 13 black
$ns color 14 pink
$ns color 15 magenta
$ns color 16 violet
$ns color 17 red
$ns color 18 blue
$ns color 19 cyan
$ns color 20 green
$ns color 21 orange
$ns color 22 black
$ns color 23 yellow
$ns color 24 purple
$ns color 25 gold
$ns color 26 chocolate
$ns color 27 brown
$ns color 28 tan
$ns color 29 black
$ns color 30 pink
$ns color 31 magenta
$ns color 32 violet
$ns color 33 red
$ns color 34 blue
$ns color 35 cyan
$ns color 36 green
$ns color 37 orange
$ns color 38 black
$ns color 39 yellow
$ns color 40 purple
$ns color 41 gold
$ns color 42 chocolate
$ns color 43 brown
$ns color 44 tan
$ns color 45 black
$ns color 46 pink
$ns color 47 magenta
$ns color 48 violet

#Tracing
set fname ex3-sample
set fall [open $fname.tr w]
$ns trace-all $fall
set fnam [open $fname.nam w]
$ns namtrace-all $fnam

# post processing
proc finish {} {
    global ns fall fnam
    $ns flush-trace
    close $fall
    close $fnam
    exit 0
}
# start-all
proc produces {size} {
    global ns nums req res tcps reqsize
    for {set i 0 } {$i < $nums} {incr i 1} {
        $tcps($i) listen
        $req($i) send $reqsize "$res($i) app-recv $i $reqsize"
        $ns trace-annotate "[$ns now] Start Requester [set i]"
    }
}
#
# application behavior
#
Application/TcpApp instproc stop {} {
    [$self agent] close
}
Class Application/MRReq -superclass Application/TcpApp
Class Application/MRRes -superclass Application/TcpApp
Application/MRRes instproc app-recv { node size } {
    global ns req datasize
    puts "[$ns now] 1 receives $size data from $node"
    $self send $datasize "$req($node) app-recv $node $datasize"
}
Application/MRReq instproc app-recv { node size } {
    global ns
    puts "[$ns now] requester receives $size data from $node"
    $self stop
}
# topology 
#
#    s(0)         
#      \
#       \
#        \ 
#         \
# s(...)-- n(0)-----q(0)
#         /
#        /
#       /
#      / 
#    s(N) 
#
set n(0) [$ns node]
set q(0) [$ns node]

for {set i 0 } { $i < $nums } {incr i 1} {
    set s($i) [$ns node]
    $ns duplex-link $s($i) $n(0) $bw 25us DropTail
    $ns queue-limit $s($i) $n(0) 1000
    $ns queue-limit $n(0) $s($i) $bufsize
}

$ns duplex-link $n(0) $q(0) $bw 25us DropTail
$ns queue-limit $n(0) $q(0) $bufsize
$ns queue-limit $q(0) $n(0) 1000
$ns duplex-link-op $n(0) $q(0) queuePos 0.5

Agent/TCP/FullTcp instproc done {} {
    global ns
    puts "[$ns now] TCP proc done called"
}

# Transport and Application
for {set i 0 } { $i < $nums } {incr i 1} {
    set tcpq($i) [new Agent/TCP/FullTcp]
    $tcpq($i) set class_ $i

    $tcpq($i) set minrto_ $rto
    $tcpq($i) set maxrto_ $rto
    $ns attach-agent $q(0) $tcpq($i)

    set tcps($i) [new Agent/TCP/FullTcp]
    $tcps($i) set class_ $i

    $tcps($i) set minrto_ $rto
    $tcps($i) set maxrto_ $rto
    $ns attach-agent $s($i) $tcps($i)

    set req($i) [new Application/MRReq $tcpq($i)]
    set res($i) [new Application/MRRes $tcps($i)]

    $ns connect $tcpq($i) $tcps($i)
    $req($i) connect $res($i)
}

#
# Scenario
#
$ns at 0 "produces $datasize"
$ns at 10.0 "finish"

$ns run

