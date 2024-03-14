local function onRequest(req, res)
    res.setStatusCode(200)
    res.setResponseHeader("Content-Type", "text/html")
    res.write(fs.open("index.html","r").readAll())
    res.close()
end

http.listen(15008, onRequest)
