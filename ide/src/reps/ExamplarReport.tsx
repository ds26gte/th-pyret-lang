
import React from 'react';
// TODO(joe): is this a bad import to have in the view? Should we have a more intermediate datatype like ChunkResults or no?
import { CompileAndRunResult } from '../control';
import { FaBug, FaBugSlash } from "react-icons/fa6";
import CodeEmbed from '../CodeEmbed';
import { CMEditor, parseLocation } from '../utils';
import { UninitializedEditor } from '../chunk';
import FailureComponent from '../FailureComponent';
import { RenderedCheckResultsAndSummary } from '../../../src/runtime/checker';
import { Failure } from '../failure';

type ExamplarResult = { success: boolean, result: CompileAndRunResult };

type ExamplarReportProps = {
    wheatResults: ExamplarResult[],
    chaffResults: ExamplarResult[],
    editor: UninitializedEditor | CMEditor,
    hintMessage: string,
    qtmVariations: number
};
type ExamplarReportState = {};

function resultSummary(wheatResultArray: ExamplarResult[], chaffResultArray: ExamplarResult[], hintMessage: string, qtmVariations: number) {
  function numFailures(resultArray: any[]) {
    const fails = resultArray.filter((result) => !result.success);
    return fails.length;
  }

  function pluralize(noun: string, num: number) {
    if (noun == "bug") {
      return num + " " + ((num > 1)? "bugs" : "bug");
    } else {
      return num + " " + ((num > 1)? "butterflies" : "butterfly");
    }
  }

  const numWheats = wheatResultArray.length;
  const numChaffs = chaffResultArray.length;
  const wheatFails = numFailures(wheatResultArray);
  const chaffFails = numFailures(chaffResultArray);
  const wheatSuccs = numWheats - wheatFails;
  const chaffSuccs = numChaffs - chaffFails;
  let qtmMessage = '';
  let introMessage = '';
  let wheatMessage = '';
  let chaffMessage = '';
  //
  if (numWheats === 0) {
    if (numChaffs === 0) {
      introMessage = `There were no bugs to swat and no butterflies to save.`;
    } else if (chaffFails === numChaffs) {
      introMessage = `You swatted all ${pluralize("bug", numChaffs)}, but there were no butterflies to save.`;
    } else { // chaffFails < numChaffs
      introMessage = `You swatted ${chaffFails} of ${pluralize("bug", numChaffs)}, but there were no butterflies to save.`;
    }
  } else if (wheatFails === 0) {
    if (numChaffs === 0) {
      introMessage  = `All ${pluralize("butterfly", numWheats)} made it, but there were no bugs to swat.`;
    } else if (chaffFails === numChaffs) {
      introMessage  = `All ${pluralize("butterfly", numWheats)} made it, and you swatted all ${pluralize("bug", numChaffs)}.`;
    } else { // chaffFails < numChaffs
      introMessage  = `Only ${pluralize("butterfly", numWheats)} made it, and you swatted only ${chaffFails} of ${pluralize("bug", numChaffs)}.`;
    }
  } else { // wheatSuccs < numWheats
    if (numChaffs === 0) {
      introMessage  = `Only ${wheatSuccs} of ${numWheats} butterflies made it, and there were no bugs to swat.`;
    } else if (chaffFails === numChaffs) {
      introMessage  = `You swatted all ${pluralize("bug", numChaffs)}, but only ${wheatSuccs} of ${pluralize("butterfly", numWheats)} made it.`;
    } else {
      introMessage  = `You swatted only ${chaffFails} of ${pluralize("bug", numChaffs)}, and only ${wheatSuccs} of ${pluralize("butterfly", numWheats)} made it.`;
    }
  }
  //
  // eslint-disable-next-line
  /*
  if (qtmVariations >= 0) { // disable for now
    qtmMessage = `Quartermaster: found ${qtmVariations} variants of input/output. `;
  }
  */
  if (introMessage !== '') {
    if (wheatMessage !== '' || chaffMessage !== '' || hintMessage !== '') {
      introMessage += ' ';
    }
  }
  if (wheatMessage !== '') {
    if (chaffMessage !== '' || hintMessage !== '') {
      wheatMessage += ' ';
    }
  }
  if (chaffMessage !== '') {
    if (hintMessage !== '') {
      chaffMessage += ' ';
    }
  }
  if (hintMessage !== '') {
    hintMessage += ' ';
  }
  return `${qtmMessage}${introMessage}${wheatMessage}${chaffMessage}${hintMessage}`;
}

function bug() {
  return <span className="examplar-result-icon bug"></span>
}
function swattedBug() {
  return <span className="examplar-result-icon bug swatted"></span>
}

function butterfly() {
  return <span className="examplar-result-icon butterfly"></span>}
function swattedButterfly() {
  return <span className="examplar-result-icon butterfly swatted"></span>
}

function chaffWheatWidget(chaffResults: ExamplarResult[], wheatResults: ExamplarResult[]) {
  const butterflies = wheatResults.map( wr => wr.success? butterfly() : swattedButterfly() )
  const bugs        = chaffResults.map( cr => cr.success?    bug()  :   swattedBug()   )
  return <div>
    { butterflies }
    { bugs }
  </div>
}

function failingWheatTests(wheatResults: ExamplarResult[]) {
    const failResults = wheatResults.flatMap(wr => {
        if(wr.result.type !== 'run-result') { return []; }
        console.log("Wheat result: ", wr);
        // fixme: check that .$renderedChecks exists
        if (!wr.result.result.result.$renderedChecks) { return []; }
        const checks = wr.result.result.result.$renderedChecks as RenderedCheckResultsAndSummary;
        // fixme: check that .renderedChecks exists
        if (!checks.renderedChecks) { return []; }
        const failed = checks.renderedChecks.flatMap((c) => c.testResults.filter((tr) => tr.$name !== 'success'));
        if(failed.length === 0) { return []; }
        return [failed[0].rendered];
    });
    return failResults;
}

function firstFailingWheatTest(wheatResults : ExamplarResult[]) {
    const failResults = failingWheatTests(wheatResults);
    if(failResults.length === 0) {
        console.error("Tried to get failing location for successful wheat results");
        throw new Error("Tried to get failing location for successful wheat results");
    }
    console.log(failResults);
    return failResults[0];
}


function showFirstWheatFailure(wheatResults : ExamplarResult[], hintMessage: string, editor : any) {
    const firstFail = firstFailingWheatTest(wheatResults);
    console.log("wheatFailure ", firstFail);
    return <div>This test is invalid (it did not match the behavior of a wheat):
        <div>{hintMessage}</div>
        <FailureComponent failure={firstFail as Failure}/>
    </div>;
}


export default class ExamplarReportWidget extends React.Component<ExamplarReportProps, ExamplarReportState> {
  render() {
    const { wheatResults, chaffResults, hintMessage, qtmVariations, editor } = this.props;
    const failures = failingWheatTests(wheatResults);
    if(failures.length !== 0) {
        return <div>{showFirstWheatFailure(wheatResults, hintMessage, editor)}</div>
    }
    return (
      <div>{chaffWheatWidget(chaffResults, wheatResults)}<p>{resultSummary(wheatResults, chaffResults, hintMessage, qtmVariations)}</p></div>
    );
  }
}
