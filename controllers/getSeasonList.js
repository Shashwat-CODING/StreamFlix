const getInfo = require('../lib/getInfo');

async function getSeasonList(req, res) {
  const { id } = req.query;
  if (!id) {
    return res.json({
      success: false,
      message: "Please provide a valid id",
    });
  }
  try {
    const mediaInfo = await getInfo(id);
    if (!mediaInfo.success) {
      return res.json({ success: false, message: "Media not found" });
    }
    const playlist = mediaInfo?.data?.playlist;
    // if series
    const seasons = [];
    if (playlist[0]?.title.includes("Season")) {
      playlist.forEach((season, i) => {
        let totalEpisodes = playlist[i]?.folder?.length;
        let lang = [];
        playlist[i]?.folder[0]?.folder?.forEach((item) => {
          if (item?.title) lang.push(item.title);
        });
        seasons.push({
          season: season.title,
          totalEpisodes,
          lang,
        });
      });
      return res.json({
        success: true,
        data: { seasons, type: "tv" },
      });
    } else {
      // if movie
      let lang = [];
      playlist?.forEach((item) => {
        if (item?.title) lang.push(item.title);
      });
      return res.json({
        success: true,
        data: {
          seasons: [
            {
              lang,
            },
          ],
          type: "movie",
        },
      });
    }
  } catch (err) {
    console.log("error: ", err);
    res.json({
      success: false,
      message: "Internal server error",
    });
  }
}

module.exports = getSeasonList;
