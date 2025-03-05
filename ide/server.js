const express = require('express');
const app = express();
app.use(express.static(__dirname + "/build/"));

// Serve the files on port 3000.
app.listen(8081, function () {
  console.log('Example app listening on port 8081!\n');
});


