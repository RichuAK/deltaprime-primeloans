<template>
  <div id="modal" class="rtkn-pledge-modal-component modal-component">
    <Modal>
      <div class="modal__title">
        rTKN Pledge
      </div>

      <div class="modal-top-info-bar-wrapper">
        <div class="modal-top-info-bar">
          cap exceeded scaled down disclaimer
        </div>
      </div>

      <div class="modal-top-info">
        <div class="top-info__value">{{ available | smartRound }}<span class="top-info__currency"> rTKN</span>
        </div>
      </div>

      <CurrencyInput v-on:newValue="pledgeValueChange"
                     :symbol="assetSymbol"
                     :validators="validators"
                     :max="available">
      </CurrencyInput>

      <div class="pledge-data">
        <div class="pledge-data__entry">
          <div class="entry__label">
            Total rTKN Cap:
          </div>
          <div class="entry__value">
            {{ rtknCap | smartRound }} rTKN
          </div>
        </div>

        <div class="pledge-data__entry">
          <div class="entry__label">
            Total rTKN Pledged:
          </div>
          <div class="entry__value">
            {{ totalPledged | smartRound }} rTKN
          </div>
        </div>

        <div class="pledge-data__entry">
          <div class="entry__label">
            Progress:
          </div>
          <div class="entry__value">
            <BarGaugeBeta :min="0" :max="rtknCap" :value="totalPledged"></BarGaugeBeta>
          </div>
        </div>

        <div class="pledge-data__entry">
          <div class="entry__label">
            Total users pledged:
          </div>
          <div class="entry__value">
            {{ totalUsers | smartRound }}
          </div>
        </div>


      </div>

      <div class="transaction-summary-wrapper">
        <TransactionResultSummaryBeta>
          <div class="summary__values">
            <div class="summary__value__pair">
              <div class="summary__label">
                Remaing rTKN:
              </div>
              <div class="summary__value">
                {{ rtknCap - totalPledged - pledgeValue | smartRound }} rTKN
              </div>
            </div>
            <div class="summary__divider divider--long"></div>
            <div class="summary__value__pair">
              <div class="summary__label">
                Your pledge:
              </div>
              <div class="value__wrapper">
                <div class="summary__value">
                  {{ userPledged + pledgeValue | smartRound }} rTKN
                </div>
              </div>
            </div>
            <div class="summary__divider divider--long"></div>
            <div class="summary__value__pair">
              <div class="summary__label">
                ~Eligible PRIME
              </div>
              <div class="value__wrapper">
                <div class="summary__value">
                  {{ (userPledged + pledgeValue) * conversionRatio | smartRound }} PRIME
                </div>
              </div>
            </div>
          </div>
        </TransactionResultSummaryBeta>
      </div>

      <div class="button-wrapper">
        <Button :label="'Pledge'"
                v-on:click="submit()"
                :waiting="transactionOngoing"
                :disabled="inputValidationError">
        </Button>
      </div>
    </Modal>
  </div>
</template>

<script>
import Modal from './Modal';
import TransactionResultSummaryBeta from './TransactionResultSummaryBeta';
import CurrencyInput from './CurrencyInput';
import Button from './Button';
import Toggle from './Toggle';
import ethers from 'ethers';
import addresses from '../../common/addresses/avalanche/token_addresses.json';
import erc20ABI from '../../test/abis/ERC20.json';
import config from '../config';
import BarGaugeBeta from './BarGaugeBeta.vue';

export default {
  name: 'RtknPledgeModal',
  components: {
    BarGaugeBeta,
    Button,
    CurrencyInput,
    TransactionResultSummaryBeta,
    Modal,
    Toggle
  },

  props: {
    walletAssetBalance: null,
    pledge: 0,
    assetSymbol: null,
    available: null,
    userPledged: null,
    rtknCap: null,
    totalPledged: null,
    conversionRatio: null,
    totalUsers: null,
  },

  data() {
    return {
      pledgeValue: 0,
      validators: [],
      transactionOngoing: false,
      inputValidationError: false,
    };
  },

  mounted() {
    this.setupValidators();
  },

  methods: {
    submit() {
      this.transactionOngoing = true;
      const pledgeEvent = {
        value: this.pledgeValue,
      };
      this.$emit('PLEDGE', pledgeEvent);
    },

    pledgeValueChange(event) {
      console.log(event);
      this.pledgeValue = Number(event.value);
      this.inputValidationError = event.error;
    },

    setupValidators() {
      this.validators = [
        {
          validate: (value) => {
            if (value > this.available) {
              return 'Exceeds account balance';
            }
          }
        }
      ];
    },
  }
};
</script>

<style lang="scss" scoped>
@import "~@/styles/variables";
@import "~@/styles/modal";

.value__wrapper {
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;

  .asset__icon {
    cursor: pointer;
    width: 20px;
    height: 20px;
    opacity: var(--asset-table-row__icon-opacity);
  }

  .summary__value:last-child {
    margin-left: 5px;
  }
}

.pledge-data {
  margin-top: 20px;

  .pledge-data__entry {
    display: grid;
    grid-template-columns: 1fr 1fr;
    border-bottom: var(--swap-modal__slippage-bar-border);
    margin-bottom: 20px;
    padding-bottom: 10px;

    .entry__label {
      color: var(--swap-modal__slippage-advanced-color);
      font-size: $font-size-sm;
      font-weight: 500;
    }

    .entry__value {
      color: var(--swap-modal__slippage-option-pill-color);
      font-weight: 500;
      font-size: $font-size-xsm;

      .bar-gauge-beta-component {
        justify-content: flex-start !important;
      }
    }
  }
}

</style>
