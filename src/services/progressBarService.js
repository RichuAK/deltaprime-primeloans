import {Subject} from 'rxjs';

export default class ProgressBarService {

  progressBarRequested$ = new Subject();
  progressBarState$ = new Subject();

  requestProgressBar(duration = 30) {
    console.log('request progress bar');
    this.progressBarRequested$.next({duration: duration});
  }

  emitProgressBarErrorState() {
    this.requestProgressBar();
    this.progressBarState$.next('ERROR');
  }

  emitProgressBarSuccessState() {
    this.progressBarState$.next('SUCCESS');
  }

  emitProgressBarState(state) {
    this.progressBarState$.next(state);
  }

};