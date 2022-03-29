echo "Run Jupyter & VSCode & TTYD"
echo "Password: $PASSWORD"

cp -R -n /code/* /workspace

if [ "$GH_REPO" ]
then
  echo "Github Repo: $GH_REPO"
  if ["$GH_BRANCH"]
  then
    git clone -b ${GH_BRANCH} --single-branch ${GH_REPO} .
  else
    git clone ${GH_REPO} .
  fi
  git config --global user.email "$USER_EMAIL"
  git config --global user.name "$USER_NAME"
fi

if [ "$IPYNB_FILE" ]
then
  wget -nc "${IPYNB_FILE}"
fi
chmod -R 555 /workspace

# Do not change the port number 8000.
jupyter notebook  --NotebookApp.token=$PASSWORD --ip=0.0.0.0 --port=8000 --allow-root &

if [ -z "$PASSWORD" ]
then
AUTH=none
else
AUTH=password
fi

# Do not change the port number 8010.
export PORT="8010"
code-server /workspace/ --bind-addr=0.0.0.0:8010 --auth $AUTH &

if [ -z "$PASSWORD" ]
then
TTYD_PASS=
else
TTYD_PASS="-c :$PASSWORD"
fi
# Do not change the port number 8020.
ttyd -p 8020 $TTYD_PASS zsh &

tail -f /dev/null