const express = require('express');
const app = express();
console.log('starting static on', __dirname + "/build/");
app.use(express.static(__dirname + "/build/"));

const port = process.env.PORT || 8081;

// Serve the files on port 3000.
app.listen(port, function () {
  console.log('Example app listening on port 8081!\n');
});


