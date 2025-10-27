import ros_api
import argparse
import sys
import os

# Parse the arguments
parser = argparse.ArgumentParser()
parser.add_argument("action", type=str, help="[allow_PS5, block_PS5, status_PS5]")
parser.add_argument("-d", "--debug", action="store_true", help="Enable debug mode")

# load mikrotik credentials from secrets file
mikro_creds = {}
with open("/run/secrets/mikrotik", "r") as f:
    for line in f:
        line = line.strip()  # Remove leading/trailing whitespace and newline
        if line and ":" in line:  # Ensure the line is not empty and contains an '='
            username, passwd = line.split(":", 1)  # Split only on the first ':'

# The connection to the router
router = ros_api.Api('mikro-router', username.strip(), passwd.strip(), port=8728)

args = parser.parse_args()

def allow_PS5():
  control_firewall_rule_by_comment('disable', 'Block PS5')
def block_PS5():
  control_firewall_rule_by_comment('enable', 'Block PS5')
def status_PS5():
  control_firewall_rule_by_comment('check_status', 'Block PS5')

def control_firewall_rule_by_comment(verb, comment_to_match: str):
  firewall_rules = router.talk('/ip/firewall/filter/print')
  for rule in firewall_rules:
    if rule.get('comment') == comment_to_match:
      rule_id = rule.get('.id')

      if verb=='check_status':
        rule_disabled = rule.get('disabled')
        if rule_disabled == 'true':
          if args.debug:
            print(f'Rule {rule_id} disabled is {rule_disabled}, device allowed');
          sys.exit(1);
        else:
          if args.debug:
            print(f'Rule {rule_id} disabled is {rule_disabled}, device blocked');
          sys.exit(0);

      else:
        if args.debug:
          print(f"Running {verb} against firewall rule {rule_id} with comment '{comment_to_match}'")
        cmd = f'/ip/firewall/filter/{verb} =numbers={rule_id}'
        r = router.talk(cmd)
        if args.debug:
          print(r);

def main():
  func = globals().get(args.action)
  if callable(func):
    func()
  else:
    print(f"ERROR: No such action '{args.action}'.");
    return 1
  
if __name__ == "__main__":
    main()

