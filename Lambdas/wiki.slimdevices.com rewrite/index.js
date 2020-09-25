exports.handler = async (event) => {
    const request = event.Records[0].cf.request;

    const olduri = request.uri;
    let newuri = olduri;

    if (newuri.match(/index\.php\//) && !newuri.match(/\.html$/))
        newuri = newuri + '.html';

    newuri = newuri.replace(/\/User:/, '/User_');

    request.uri = newuri;

    return request;
};
