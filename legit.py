#!/usr/bin/python3

import argparse, collections, os, re, subprocess, sys, time
debug = 0

legit_commands = "add branch checkout commit diff init log merge rm show status"
.split()
LEGIT_DIRECTORY = '.legit'
GIT_DIRECTORY = os.path.join(LEGIT_DIRECTORY, '.git')
PROGRAM_NAME = 'legit.pl'

def main():
    global debug
    while sys.argv[1:] and sys.argv[1] == '-d':
        debug += 1
        sys.argv.pop(0)
    if not sys.argv[1:]:
        die(usage_message, error_type='')
    command = sys.argv[1]
    if command not in legit_commands:
        die('unknown command', command, '\n'+usage_message)
    if command != "init" and not os.path.exists(LEGIT_DIRECTORY):
        die('no', LEGIT_DIRECTORY , 'directory containing legit repository exist
s')
    elif command != "init" and not os.path.exists(GIT_DIRECTORY):
        internal_error('this repository was not created by the reference impleme
ntation')
    try:
        function = eval("legit_"+command)
    except Exception:
        die('internal error', command, 'not implemented')
    function(sys.argv[2:])

def legit_init(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' ini
t')
    parser.parse_args(commandline_args)
    if os.path.exists(LEGIT_DIRECTORY):
        die(LEGIT_DIRECTORY, 'already exists')
    try:
        os.mkdir(LEGIT_DIRECTORY)
    except OSError:
        die('could not create legit depository')
    run_git('init')
    run_git('config', 'core.fileMode', 'false')
    print('Initialized empty legit repository in .legit')

def legit_add(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' add
 <filenames>')
    parser.add_argument("filenames",  nargs='*', default=[])
    args = parser.parse_args(commandline_args)
    for filename in args.filenames:
        check_filename_local(filename)
        if not valid_legit_filename(filename):
            die('invalid filename', filename)
        if not is_filename_in_repo(filename) and not os.access(filename, os.R_OK
):
            die('can not open', filename)
        elif os.path.exists(filename) and not os.path.isfile(filename):
            die(filename, 'is not a regular file')
    run_git('add', '--force', *args.filenames)

#def legit_mv(commandline_args):
#   parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' mv 
<source> destination>')
#   parser.add_argument("source")
#   parser.add_argument("destination")
#   args = parser.parse_args(commandline_args)
#   check_filename_in_repo(args.source)
#   check_filename_local(args.destination)
#   if os.path.exists(args.destination):
#       die('destination exists', 'source='+args.source, 'destination='+args.des
tination)
#   run_git('mv', args.source, args.destination)

def legit_rm(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' rm 
[--force] [--cached] <filenames>')
    parser.add_argument("--force", action='store_true', default=False)
    parser.add_argument("--cached", action='store_true', default=False)
    parser.add_argument("filenames",  nargs='*', default=[])
    args = parser.parse_args(commandline_args)
    for filename in args.filenames:
        check_filename_local(filename)
        check_filename_in_repo(filename)

        # if filename doesn't exist safe to rm
        if not os.path.exists(filename):
            continue

        if not os.path.isfile(filename):
            die(filename, 'is not a regular file')

        working_index_identical = diff_working_index(filename)
        working_commit_identical = diff_working_commit(filename)
        index_commit_identical = diff_index_commit(filename)

        if not working_index_identical and not index_commit_identical and not ar
gs.force:
            die(filename, 'in index is different to both working file and reposi
tory')
        if not index_commit_identical and not args.force and not args.cached:
            die(filename, 'has changes staged in the index')
        if not working_commit_identical and not args.force and not args.cached:
            die(filename, 'in repository is different to working file')

    run_git('rm', *commandline_args)

def legit_commit(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' com
mit [-a] -m commit-message')
    parser.add_argument("-m", dest='message', default="")
    parser.add_argument("-a", dest='all', action='store_true', default=False)
    args = parser.parse_args(commandline_args)
    if not args.message:
        die('empty commit message')
    if '\n' in args.message or '\r' in args.message:
        die('commit message can not contain a newline')
    # we are (unwisely)? relying on commit timestamp being unique
    # timestamps have a 1 second resolution so sleep to make sure we don't get a
 collision
    time.sleep(1)
    p = run_git('commit', *commandline_args)
    if 'nothing to commit' in p.stdout or 'nothing added' in p.stdout :
        print('nothing to commit')
    else:
        commit_numbers = get_commit_numbers()
        last_commit_hash = get_commit_hash()
        print("Commited as commit", commit_numbers[last_commit_hash])

def legit_show(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' <co
mmit>:<filename>')
    parser.add_argument("object")
    args = parser.parse_args(commandline_args)
    if ':' not in args.object:
        die('invalid object', args.object)
    (commit_number, filename) = args.object.split(':', 2)
    hash = get_nth_commit_hash(commit_number) if commit_number else ''
    check_filename_local(filename)
    p = run_git('show', hash + ':' + filename, die_if_stderr=False)
    if p.stderr:
        if commit_number == '':
            die(filename, 'not found in index')
        else:
            die(filename, 'not found in commit', commit_number)
    print(p.stdout, end='')

def legit_log(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' log
')
    parser.parse_args(commandline_args)
    commit_numbers = get_commit_numbers()
    p = run_git('log', "--pretty=%H %s")
    for line in p.stdout.splitlines():
        (hash, commit_message) = line.split(' ', 1)
        print(commit_numbers[hash], commit_message)

status_explanation = {
    '  ' : 'same as repo',
    ' M' : 'changes in index',
    'M ' : 'file modified',
    'MM' : 'file modified and changes in index',
    'D ' : 'deleted',
    ' D' : 'file deleted',
    '? ' :'untracked',
    '??' :'untracked',
    ' ?' :'untracked',
    }
def legit_status(commandline_args):
    p = run_git('status', "--no-renames", "--porcelain=1")
    file_status = {}
    for line in p.stdout.splitlines():
        file_status[line.split()[-1]] = line[0:2]
    p = run_git('show', '--pretty=', '--name-only', 'HEAD')
    files_in_head = p.stdout.splitlines()
    p = run_git('ls-files', '--others', '--cached', '--deleted')
    files_in_index_and_directory = p.stdout.splitlines()
    all_files = set(files_in_head + files_in_index_and_directory)
    for filename in sorted(all_files):
        if not valid_legit_filename(filename):
            continue
        status = file_status.get(filename, '  ')
        explanation = status_explanation.get(status, 'added to index')
        print(filename, '-', explanation)

def legit_branch(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' [-d
] <branch>')
    parser.add_argument("-d", dest='delete', default=None)
    parser.add_argument("branch", nargs='?', default=None)
    args = parser.parse_args(commandline_args)

    branches = get_branches()

    if args.branch is None and args.delete is None:
        if branches:
            print("\n".join(branches))
        return

    if args.delete is not None and args.branch is not None:
        die('too many branches')

    if args.delete is not None and args.delete not in branches:
        die('branch', args.delete, 'does not exist')

    if args.branch is not None and args.branch in branches:
        die('branch', args.branch, 'already exists')

    if args.branch is not None and not re.match('^[a-zA-Z][a-zA-Z0-9_\-]+$', arg
s.branch):
        die('invalid branch name', args.branch)

    if not branches:
        die('can not create a branch until a commit is made to master')

    run_git('branch', *commandline_args, die_if_stderr=False)


def legit_checkout(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' che
ckout')
    parser.add_argument("branch")
    args = parser.parse_args(commandline_args)

    branches = get_branches()

    if args.branch not in branches:
        die('unknown branch', args.branch)
    p = run_git('checkout', args.branch, die_if_stderr=False)
    if p.stderr:
        stderr_lines = p.stderr.splitlines()
        if 'Switch' in stderr_lines[-1] or 'Already' in stderr_lines[-1]:
            print(stderr_lines[-1])
            return
        if 'files' not in stderr_lines[0]:
            internal_error(p.stderr)
        error = "Your changes to the following files would be overwritten by che
ckout:\n"
        error += "\n".join([line[1:]  for line in stderr_lines if line.startswit
h("\t")])
        die(error)

def legit_merge(commandline_args):
    parser = argparse.ArgumentParser(prog=PROGRAM_NAME, usage=PROGRAM_NAME+' mer
ge [-m <branch|commit>')
    parser.add_argument("-m", dest='message', default="")
    parser.add_argument("branch_or_commit")
    args = parser.parse_args(commandline_args)

    branches = get_branches()

    if not args.message:
        die('empty commit message')
    args = parser.parse_args(commandline_args)

    if re.match(r'^\d+$', args.branch_or_commit):
        object = get_nth_commit_hash(args.branch_or_commit)
    elif args.branch_or_commit not in branches:
        die('unknown branch', args.branch_or_commit)
    else:
        object = args.branch_or_commit

    p = run_git('merge', object)
    stdout_lines = p.stdout.splitlines()
    if 'Already up to date' in p.stdout:
        print(p.stdout)
    elif 'CONFLICT' in p.stdout:
        run_git('merge', '--abort')
        error = "These files can not be merged:\n"
        error += "\n".join(sorted([line.split()[-1]  for line in stdout_lines if
 line.startswith("CONFLICT")]))
        die(error)
    else:
        print("\n".join(sorted([line for line in stdout_lines if line.startswith
("Auto-merging")])))

def get_branch_files(branch):
    p =run_git('ls-tree', '--name-only', branch)
    return p.stdout.splitlines()

def get_branches():
    p = run_git('branch', '--format', '%(refname:short)')
    return p.stdout.splitlines()

def get_nth_commit_hash(commit_number):
    try:
        commit_hashes = list(get_commit_numbers().keys())
        return commit_hashes[int(commit_number)]
    except (ValueError, KeyError):
        die("invalid commit", commit_number)

def check_filename_local(*filenames):
    for filename in filenames:
        if '/' in filename:
            die(filename, 'contains a slash - legit filenames can not contain sl
ashes')

def check_filename_in_repo(*filenames):
    for filename in filenames:
        if not is_filename_in_repo(filename):
            die(filename, 'is not in the legit repository')

def is_filename_in_repo(filename):
    return check_git('ls-files', '--error-unmatch', filename)

def diff_working_index(filename):
    return check_git('diff', '--exit-code', filename)

def diff_index_commit(filename, commit='HEAD'):
    return check_git('diff', commit, '--cached', '--exit-code', filename)

def diff_working_commit(filename, commit='HEAD'):
    return check_git('diff', commit, '--exit-code', filename)

def get_commit_hash(commit='HEAD'):
    p = run_git('rev-parse', commit)
    return p.stdout.strip()

# return dict of git hashes mapped to integers 0..n chronologically
def get_commit_numbers():
    p = run_git('reflog', "--pretty=%cI %H", die_if_stderr=False)
    commit_number = 0
    hashes = collections.OrderedDict()
    for line in sorted(p.stdout.splitlines()):
        (timestamp, hash) = line.split()
        if hash not in hashes:
            hashes[hash] = commit_number
            commit_number += 1
    return hashes

def valid_legit_filename(filename):
    return re.match('^[a-zA-Z0-9][a-zA-Z0-9_\-.]*$', filename)

def check_git(*args):
    p = run_git(*args, die_if_stderr=False)
    return p.returncode == 0

def run_git(*args, die_if_stderr=True):
    command = ['git'] + list(args)
    if debug:
        print('running:', ' '.join(command), file=sys.stderr)
    p = subprocess.run(command, input='', stdout=subprocess.PIPE, stderr=subproc
ess.PIPE, universal_newlines=True)
    if p.stderr and die_if_stderr:
        internal_error(p.stderr)
    return p

def internal_error(message):
    die('internal error', message, '\nYou are not required to detect this error 
or produce this error message.')

def die(*args, **kwargs):
    error_type = kwargs.setdefault('error_type', 'error')
    del kwargs['error_type']
    kwargs.setdefault('file', sys.stderr)
    if error_type in ["error"]:
        print(PROGRAM_NAME + ':', error_type + ':', *args, **kwargs)
    elif error_type:
        print(error_type + ':', *args, **kwargs)
    else:
        print(*args, **kwargs)
    sys.exit(1)

usage_message = 'Usage: ' + PROGRAM_NAME + """ <command> [<args>]

These are the legit commands:
   init       Create an empty legit repository
   add        Add file contents to the index
   commit     Record changes to the repository
   log        Show commit log
   show       Show file at particular state
   rm         Remove files from the current directory and from the index
   status     Show the status of files in the current directory, index, and repo
sitory
   branch     list, create or delete a branch
   checkout   Switch branches or restore current directory files
   merge      Join two development histories together
"""

if __name__ == "__main__":
    for variable in os.environ:
        os.environ.pop(variable, None)
    os.environ['PATH'] = '/usr/local/bin:/usr/bin:/bin'
    os.environ['LANG'] = 'en_AU.utf8'
    os.environ['LANGUAGE'] = 'en_AU:en'
    os.environ['LC_COLLATE'] = 'POSIX'
    os.environ['LC_NUMERIC'] = 'POSIX'
    os.environ['GIT_DIR'] = GIT_DIRECTORY
    os.environ['GIT_WORK_TREE'] = '.'
    os.environ['GIT_AUTHOR_NAME'] = 'COMP[29]041 Student'
    os.environ['GIT_AUTHOR_EMAIL'] = 'cs2041@example.com'
    main()
    sys.exit(0)
