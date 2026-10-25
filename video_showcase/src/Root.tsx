import React from 'react';
import {Composition} from 'remotion';
import {AppShowcaseSequence} from './AppShowcaseSequence';
import timeline from './timeline.json';

export const Root: React.FC = () => {
  return (
    <Composition
      id="ArogyaShowcase"
      component={AppShowcaseSequence}
      durationInFrames={timeline.durationInFrames}
      fps={timeline.fps}
      width={timeline.width}
      height={timeline.height}
    />
  );
};
