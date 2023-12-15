# trainmon

This addon for Ashita v4 tracks and displays Training Regime objectives. It supports both English and Japanese clients.

![Example](https://github.com/onimitch/ffxi-trainmon/blob/main/Example.png "Example")


## How to install:
1. Download the latest Release from the [Releases page](https://github.com/onimitch/ffxi-trainmon/releases)
2. Extract the **_trainmon_** folder to your **_Ashita4/addons_** folder

## How to have Ashita load it automatically:
1. Go to your Ashita v4 folder
2. Open the file **_Ashita4/scripts/default.txt_**
3. Add `/addon load trainmon` to the list of addons to load under "Load Plugins and Addons"

## Usage

Go to a Field Manual and start a training regime. If you've already started one then confirm the training options to update trainmon.
By default the training objectives will only display while you're in the zone the training is for.
You can drag the window by mouse click and hold on the arrow icon.

## Commands

You can use `/trainmon` or `/tmon`

`/trainmon status` - Show in chat log the current training data.
`/trainmon reset` - Clear all training data from trainmon. Note this doesn't cancel your training regime with the game, it just stops the addon tracking your kills.
`/trainmon hide` - Hide the training window
`/trainmon show` - Show the training window only in the zone the training is for.
`/trainmon show always` - Show the training window in all zones, regardless of what zone the training is for.

## Issues/Support

I only have limited time available to offer support, but if you have a problem, have discovered a bug or want to request a feature, please [create an issue on GitHub](https://github.com/onimitch/ffxi-trainmon/issues).
