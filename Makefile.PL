use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'Net::NATS::Client',
    VERSION_FROM    => 'lib/Net/NATS/Client.pm',
    PREREQ_PM       => {
        'Class::XSAccessor' => 0
    },
);
