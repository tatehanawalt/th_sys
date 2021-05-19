# be sure to follow the `adding your changes` (last section of the README) when pushing changes to git

# Steps for the first brew installable hello world

# 1. Choose any language but preferably python

# 2. Create a file called main.py and make it executable (chmod 744 <filename>)

# 3. Add code so the file can be executed as 'main' or essentially a cli - The code for this is outlined in the url: https://realpython.com/python-main-function/

# 4. Add a 'Python Shebang' as the FIRST line in the main.py file. the shebang defines the tool the environment will use to interpret the file. This lets you run the python main.py without calling python <main.py> instead you can just run ./main.py

# 5. Symlink the main.py file into your $PATH.

   Specifically `ln -s <path/to/file/main.py> /usr/local/bin/demopython`

# 6. DONE

### At this point you should be able to type `demopython`. The system will search $PATH for an `executable` named `demopython`. The system will check for the shebang at the FIRST line of the file, (the target of the symlink). If the shebang is correct the system will run the file using the shebang specified interpreter


Now log in to Github and visit the repository, you should see a button that says something like 'create pull request' click that and wing it and well talk about it when we have a chance
