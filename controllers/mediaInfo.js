const getInfo = require('../lib/getInfo');

async function mediaInfo(req, res) {
  const { id } = req.query;
  if (!id) {
    return res.json({
      success: false,
      message: "Please provide a valid id",
    });
  }
  try {
    const data = await getInfo(id);
    res.json(data);
  } catch (err) {
    console.log("error: ", err);
    res.json({
      success: false,
      message: "Internal server error",
    });
  }
}

module.exports = mediaInfo;
