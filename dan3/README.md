# be sure to follow the `adding your changes` (last section of the README) when pushing changes to git

# Steps for the first brew installable hello world

# 1. Choose any language but preferably python

# 2. Create a file called main.py and make it executable (chmod 744 <filename>)

# 3. Add code so the file can be executed as 'main' or essentially a cli - The code for this is outlined in the url: https://realpython.com/python-main-function/

# 4. Add a 'Python Shebang' as the FIRST line in the main.py file. the shebang defines the tool the environment will use to interpret the file. This lets you run the python main.py without calling python <main.py> instead you can just run ./main.py

# 5. Symlink the main.py file into your $PATH.
   You can type `echo $PATH` to see the path, you can type `echo $PATH | tr ':' '\n'` to see the paths on separate lines. You can type `echo $PATH | tr ':' '\n' | sort` to see them alphabetized (and you can add `-u` after `sort` to show only unique entries)

   #### Adding the path executable:
   You create a symbolic link with `ln -s <source> <target>` where `source` is the full path to the file and `target` is the path where the symbolic link will be located.

   You can rename the symbolic link anything. Because this will be a brew file and the project is `dan3` we will be linking this as `dan3`

   The link will go in ANY of the directories in your `$PATH`. The system will search the paths in the order they are printed before using `sort` so the earlier the better but the first fiew paths are usually indeded for root/admin/sudo or system level utils so put the symlink assuming this path is in your $PATH use `/usr/local/bin`.

   Specifically `ln -s <path/to/file/dan3.py> /usr/local/bin/dan3`

# 6. DONE

### At this point you should be able to type `dan3`. The system will search $PATH for an `executable` named `dan3`. The system will check for the shebang at the FIRST line of the file. If the shebang is correct the system will run the file using the shebang specified interpreter

# ADDING YOUR CHANGES

1. don't push directly to main. Instead, checkout a branch `git checkout -b dan-start-python-brew-cli-project`. Then commit your changes `git add <files you added>`, `git commit -m <summary of what was added>`, then push to your branch `git push origin/dan-start-python-brew-cli-project`

Now log in to Github and visit the repository, you should see a button that says something like 'create pull request' click that and wing it and well talk about it when we have a chance
