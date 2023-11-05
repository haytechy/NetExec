from argparse import _StoreTrueAction


def proto_args(parser, std_parser, module_parser):
    winrm_parser = parser.add_parser("winrm", help="own stuff using WINRM", parents=[std_parser, module_parser])
    winrm_parser.add_argument("-H", "--hash", metavar="HASH", dest="hash", nargs="+", default=[], help="NTLM hash(es) or file(s) containing NTLM hashes")
    winrm_parser.add_argument("--port", nargs="+", default=["5985", "5986"], help="Custom WinRM port, default is %(default)s, format: 'http-port https-port'(with space separated) or 'single-port'"
                              "(http & https will use same port when given single port)")
    winrm_parser.add_argument("--check-proto", nargs="+", default=["http", "https"], help="Choose what prorocol you want to check, default is %(default)s, format: 'http https'(with space separated) or 'single-protocol'")
    winrm_parser.add_argument("--laps", dest="laps", metavar="LAPS", type=str, help="LAPS authentification", nargs="?", const="administrator")
    winrm_parser.add_argument("--http-timeout", dest="http_timeout", type=int, default=10, help="HTTP timeout for WinRM connections")
    winrm_parser.add_argument("--no-smb", action=get_conditional_action(_StoreTrueAction), make_required=[], help="No smb connection")

    dgroup = winrm_parser.add_mutually_exclusive_group()
    dgroup.add_argument("-d", metavar="DOMAIN", dest="domain", type=str, default=None, help="domain to authenticate to")
    dgroup.add_argument("--local-auth", action="store_true", help="authenticate locally to each target")

    cgroup = winrm_parser.add_argument_group("Credential Gathering", "Options for gathering credentials")
    cegroup = cgroup.add_mutually_exclusive_group()
    cegroup.add_argument("--sam", action="store_true", help="dump SAM hashes from target systems")
    cegroup.add_argument("--lsa", action="store_true", help="dump LSA secrets from target systems")

    cgroup = winrm_parser.add_argument_group("Command Execution", "Options for executing commands")
    cgroup.add_argument("--codec", default="utf-8", help="Set encoding used (codec) from the target's output (default: utf-8). If errors are detected, run chcp.com at the target & map the result with https://docs.python.org/3/library/codecs.html#standard-encodings and then execute again with --codec and the corresponding codec")
    cgroup.add_argument("--no-output", action="store_true", help="do not retrieve command output")
    cgroup.add_argument("-x", metavar="COMMAND", dest="execute", help="execute the specified command")
    cgroup.add_argument("-X", metavar="PS_COMMAND", dest="ps_execute", help="execute the specified PowerShell command")

    return parser


def get_conditional_action(baseAction):
    class ConditionalAction(baseAction):
        def __init__(self, option_strings, dest, **kwargs):
            x = kwargs.pop("make_required", [])
            super().__init__(option_strings, dest, **kwargs)
            self.make_required = x

        def __call__(self, parser, namespace, values, option_string=None):
            for x in self.make_required:
                x.required = True
            super().__call__(parser, namespace, values, option_string)

    return ConditionalAction