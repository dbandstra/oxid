# Deploying to GitHub Pages

```sh
git checkout gh-pages
git reset --hard master

git checkout v1.0.2  # or whatever the latest official release is
git submodule update
sh build_web.sh docs

git checkout master
git submodule update
sh build_web.sh docs/master

git checkout gh-pages
git add docs
git commit -m "build for web"
git push -f
```
