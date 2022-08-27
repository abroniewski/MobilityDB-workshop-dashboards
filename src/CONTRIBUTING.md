MobilityDB uses DocBook v4.5. The instructions below provide a step-by-step guide to convert from a Notion export to the XML format required to successfully compile using dblatex. The process uses a tool called pandoc to convert into DocBook v5 and then some manual editing to work with v4.5 of DocBook.

---START---

Export from notion to Markdown
Change folder to "images"
Rename file to AIS_Dashboard

IN MARKDOWN
Find and replace image folder
    "(Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/"
    with "(images/"
Find and replace "%20"
    with " "
Refactor all image file names (use caption as image name, refactor name + pascal case)
Remove initial heading
Remove all caption duplicate text

IN TERMINAL
cd [folder with markdown]
pandoc FlightDataDashboard.md -f markdown -t docbook5 -s -o FlightDataDashboard.xml

IN XML
Delete header information "<!DOCTYPE ... </info>"
Insert <chapter id ="AIS_Dashboard"> at beginning
Insert <title>Dashboard and Visualization of Ship Trajectories (AIS)</title>
Remove </article> at end
Insert </chapter> at end
Find/replace "<link xlink:href"
    with "<ulink url"
Find/replace "</link>"
    with "</ulink>"
Find/replace "<imagedata fileref"
    with "<imagedata width='80%' fileref"
    note: some pictures will need to have their width set manually.
Remove <section xml:id=...> from XML file
Remove </section> from XML file
Replace "<"
    with "&lt;"
Replace ">"
    with "&gt;"

COPY AIS_Dashboard.xml into parent doc folder
COPY all images from the notion export folder into the doc/images folder

IN mobilitydb-workshop.xml
ADD <!ENTITY GPX SYSTEM "[filename].xml"> at header
ADD &FlightDataDashboard; at end

IN TERMINAL
cd ..
dblatex -s texstyle.sty -T native -t pdf -o mobilitydb-workshop.pdf mobilitydb-workshop.xml

TODO: change image filename