# -*- coding: utf-8 -*-
# Copyright 2015 Neil Freeman
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import argparse
from time import sleep
import twitter_bot_utils as tbu
from tweepy import TweepError
from . import __version__ as version
from .everylot import EveryLot


def main():
    parent = tbu.args.parent(version, config_only=True)
    parser = argparse.ArgumentParser(description='every lot twitter bot', parents=(parent,))
    parser.add_argument('user', type=str)
    parser.add_argument('database', type=str)
    parser.add_argument('--id', type=str, default=None)
    parser.add_argument('-s', '--search_format', type=str, default=None)
    parser.add_argument('-p', '--print_format', type=str, default=None)

    args = parser.parse_args()

    api = tbu.api.API(args.user)

    logger = tbu.args.add_logger(args.user, verbose=args.verbose)

    logger.debug('everylot starting with %s, %s', args.user, args.database)

    el = EveryLot(args.database,
                  logger=logger,
                  print_format=args.print_format,
                  search_format=args.search_format,
                  id_=args.id)

    if not el.lot:
        logger.error('No lot found')
        return

    logger.debug('%s addresss: %s zip: %s', el.lot['id'], el.lot.get('address'), el.lot.get('zip'))
    logger.debug('db location %s,%s', el.lot['lat'], el.lot['lon'])

    # get the streetview image and upload it
    image = el.get_streetview_image(api.config['streetview'])
    media = api.media_upload('sv.jpg', file=image)

    # compose an update with all the good parameters
    # including the media string.
    update = el.compose(media.media_id_string)
    logger.info(update['status'])

    if not args.dry_run:
        try:
            logger.debug("posting")
            api.update_status(**update)

        except TweepError as e:
            if e.message[0]['code'] == 503:
                sleep(10)
                api.update_status(**update)
            else:
                raise e

        el.mark_as_tweeted()


if __name__ == '__main__':
    main()
